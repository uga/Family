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

### A client DOES hear its own guild-channel addon message, measured on Mists 2026-08-30

Sending on the `GUILD` addon channel **does** come back to the sender on Mists of Pandaria
Classic. Measured on a live client that was the only one running Family online in its guild:

    messages sent from here: 2
    what the client answered to those: 2 x number 0
    addon messages the client handed us: 4, 2 of them Family's
        (last from Eccebombo-MirageRaceway on GUILD)
    announcements arrived: 2  (2 ours coming back, 0 for another guild, 0 unreadable)
    announcements from somebody else: none

Unambiguous because nobody else was there: with `from somebody else: none`, the two arrivals
can only be this client's own two announcements returning, and the channel they arrived on is
named.

**It also settles how the sender is spelled.** The client's own message comes back as
`Eccebombo-MirageRaceway`, in the same second that `UnitName("player")` answers `Eccebombo`.
The realm is present on one side of that comparison and absent on the other, which is what
`Guild:ProbeNames` was built to follow up.

#### This entry previously said the opposite, and how that happened is the useful part

It read *"a client does not hear its own guild-channel addon message"*, from a live diagnosis
showing `announcements arrived: 1 (0 ours coming back)` across three runs - somebody else's
announcement received perfectly well, and never once its own.

Those runs are not disputed. **The conclusion drawn from them was: no echo was seen, therefore
this client cannot echo.** That is §2.2 - not seen is not the same as not there - applied to
Family's own instrumentation rather than to the game's, and it went into this file as a
measurement because a number was quoted beside it.

What actually differed between those runs and this one is **not known**, and is not guessed at
here. The runs that showed no echo also showed `addon messages the client handed us: 0` - the
client handing over nothing whatever, from any addon - so they may be the same unexplained
silence rather than evidence about echoing at all. That silence is still unexplained.

**Era does too, measured 2026-08-30.** As the only Family user online in a 773-member guild:
`messages sent from here: 2`, `announcements arrived: 2 (2 ours coming back)`,
`announcements from somebody else: none`. Nobody else was there, so both arrivals can only be
this client's own announcements returning, and the last was named `Nervina-PyrewoodVillage on
GUILD`.

**Burning Crusade does too, measured the same day.** Sole guildie online: `sent 2`,
`announcements arrived: 2 (2 ours coming back)`, `from somebody else: none`, the last named
`Milionario-Thunderstrike on GUILD`.

**So all three clients echo**, and the entry this replaced said the opposite of the first one
measured. The diagnosis still gates its "your announcements are not coming back" branch on
having heard somebody else - not now because echoing is in doubt, but because an echo takes a
round trip and a diagnosis run in the second after an announcement would otherwise accuse a
healthy client.

### What a client calls a character, measured on Mists 2026-08-30

`/family guild names`, on Mists of Pandaria Classic, realm Mirage Raceway:

    UnitName("player")        -> 1:Eccebombo(string) 2:nil(nil)
    UnitFullName("player")    -> 1:Eccebombo(string) 2:MirageRaceway(string)
    GetRealmName()            -> 1:Mirage Raceway(string)
    GetNormalizedRealmName()  -> 1:MirageRaceway(string)
    GetAutoCompleteRealms()   -> 1:{MirageRaceway, Shek'zeer, Garalon, Norushen,
                                    Hoptallus}(table)

**Four spellings of one realm, and the addon channel uses the normalised one.** A sender
arrives as `Eccebombo-MirageRaceway` - no space - which matches `GetNormalizedRealmName` and
the second return of `UnitFullName`, and does not match `GetRealmName`. Apostrophes survive
normalising (`Shek'zeer`); spaces do not.

**`UnitName("player")` answers the realm as nil**, so a comparison built on it has no realm to
use even when the other side carries one. That is the shape behind `Guild:ProbeNames` existing
at all: `onHello` compares `bareName(sender)` against `bareName(UnitName("player"))`, and the
sender's realm is discarded rather than absent.

**Five connected realms.** A guild can therefore hold characters from any of the five, which
is the precondition for two characters of one name being in one guild. **Whether that can
actually happen is not measured** - it needs a duplicate name inside one connected group, and
nothing here establishes that connected realms permit one. The one same-named pair available
(`Eccebombo` on Mirage Raceway and on Hydraxian Waterlords) is no use: Hydraxian Waterlords is
an Era realm, outside this cluster and unable to share a guild with it.

**The roster, once it was asked for and read back:**

    GetNumGuildMembers()  -> 1:5(number) 2:2(number)
    GetGuildRosterInfo(1) -> 1:Minttuu-Shek'zeer(string) 2:Member(string) 3:3(number)
                             4:14(number) 5:Hunter(string) 6:Westfall(string)
                             7:(string) 8:(string) 9:true(boolean) 10:0(number)
                             11:HUNTER(string) 12:20(number) 13:2(number)
                             14:false(boolean) 15:false(boolean) 16:6(number)
                             17:Player-4454-062C5110(string)

**`GetNumGuildMembers` answers in two values** - total and online - and that is not a detail.
`tonumber(Family:TryCall(GetNumGuildMembers))` passed both on, `tonumber`'s second parameter is
a base, and five read in binary is nil. The probe reported an empty guild while standing in a
guild of five, twice, with valid Lua throughout. See L-031.

**A guild holds characters from other realms in the connected group, measured.** Entry 1 is
`Minttuu-Shek'zeer` in a guild on Mirage Raceway. So the roster carries a realm on the name for
a member from another realm of the cluster, and cross-realm guild membership is a fact here
rather than an inference from `GetAutoCompleteRealms`.

**Every roster entry carries a realm, including same-realm ones.** Five entries, five of them
qualified: `Minttuu-Shek'zeer` from another realm of the cluster, and `Eccebombo-MirageRaceway`,
`Pinetta-MirageRaceway`, `Pinuccia-MirageRaceway` from the player's own. So the roster never
hands back a bare name on this client, which matches what the addon channel does with senders -
this client's own guild announcement comes back qualified too. **`UnitName("player")` is the
only one of these that answers without a realm.**

**No collision in this guild.** Five members, nobody sharing a name. The hazard is not
demonstrable here today, which is not the same as it being impossible.

**What is still not measured** is a *duplicate name* inside one connected group, which is what
the collision in `onHello` would need. Two characters called Eccebombo exist on this account,
on Mirage Raceway and on Hydraxian Waterlords - but those realms are not connected (the second
is Era), they cannot share a guild, and the pair therefore says nothing about the case. Nothing
here establishes that a connected group permits a duplicate at all.

**A same-named pair exists in this tree already.** Hovering a Copper Bar draws two rows -
`Eccebombo (@Mirage Raceway)` and `Eccebombo (@Hydraxian Waterlords)` - so the panels do
disambiguate by realm where two characters share a name, and they have to. `onHello`'s echo
guard and `Guild:IsOurs` compare bare names with the realm stripped, which is the same
codebase holding two standards for the same question. It costs nothing here because those two
realms are not connected and cannot share a guild (see above), but the ambiguity is in the
data rather than in a hypothetical.

**Position 17 is a GUID** (`Player-4454-062C5110`), which is an identifier in §2.1's sense and
survives every renaming and realm question a name does not. `CHAT_MSG_ADDON` does not carry
one, so it is not available where the comparison that matters is made - noted because it is the
first thing anybody will reach for.

### A guild spans a connected group, and a character's realm is its own, measured 2026-08-30

Guild *Uga* holds `Eccebombo-MirageRaceway`, `Pinetta-MirageRaceway` and `Zinetta-Garalon` at
once. `Guild:Current()` answers `Uga (realm Mirage Raceway)` on one and `Uga (realm Garalon)`
on the other — **the same guild, and the two clients do not agree what realm it is on.** This
is the fact `Guild:Key` sets out and the reason the key never crosses the wire; what crosses is
the guild's *name*, and `forThisGuild` compares names, so the exchange is unaffected.

What *is* affected is `Offering()`, which takes our characters on `meta.guild == name and
meta.realm == realm`. Measured on Zinetta: Pinetta is in the same guild, on the same account,
and is not offered. See GUILD-CRAFTERS §7.0.

### A character on a partner realm cannot **send** on the guild addon channel, measured on Mists 2026-08-30

In guild *Uga*, spanning a connected group of five realms:

| character | realm | `GUILD` send | own echo | reached others | `GUILD` receive | whisper |
|---|---|---|---|---|---|---|
| Eccebombo (GM) | Mirage Raceway | yes | yes | yes | yes | yes |
| Pinetta | Mirage Raceway | yes | yes | yes | yes | yes |
| Zinetta | Garalon | **no** | **no** | **no** | yes | yes |

Zinetta's client accepts every send - `9 x number 0`, the same answer it gives when a message
does arrive - and the message then does not exist. Not for Eccebombo, and **not for Zinetta
herself**, which is what rules out every explanation involving the other end or the distance
between them.

**What was eliminated, each by measurement rather than by argument:**

- **Guild chat permission.** `/g` carries both ways between Zinetta and Eccebombo, with Zinetta
  an Initiate.
- **Rank.** Zinetta was promoted above Initiate and nothing changed - `sent` rose from 5 to 7,
  every send accepted, `ours coming back` still 0. Pinetta transmits perfectly *without* being
  promoted.
- **The account.** Pinetta and Zinetta are on the same account; one transmits, one does not.
- **Cross-realm delivery in general.** Eccebombo's `GUILD` announcements reach Zinetta, and
  Zinetta's whispers reach Eccebombo. Only her `GUILD` *sends* vanish.
- **Family's sending path.** `Comm:Send` chunks and queues identically either way, and the
  client answers `0` to every piece.

**What is not established** is the exact rule. One partner-realm character was tested, on a
guild created on Mirage Raceway, so *"the realm the guild is on"*, *"the realm the guild was
created on"* and *"any realm but one"* all fit equally. `Guild:Current()` reports the
**character's** realm and Family has no call that reports the guild's, so Family cannot ask the
question directly - what it can observe is its own echo failing to come back.

**Why it matters to §7.** A character on a partner realm can never announce, so nobody learns
they run Family unless somebody else announces first - and then the reply, being a whisper,
works. The exchange is not broken; the *opening* of it is, in one direction, for part of the
guild. It also makes GUILD-CRAFTERS §7.0 worth fixing for a second reason: routing a
partner-realm character's records through a home-realm character of the same account is the one
path that reaches the guild at all.

### Mists answers with both identifiers, measured 2026-08-30

`/family recipes` on Mists of Pandaria Classic, with the smelting window open:

    Mining:  8 recipe(s), 8 with a spell id, 8 with an item id
      Smelt Mithril  spell 10097 -> Smelt Mithril  item 3860 -> Mithril Bar
      Smelt Gold     spell 3308  -> Smelt Gold     item 3577 -> Gold Bar
      Smelt Iron     spell 3307  -> Smelt Iron     item 3575 -> Iron Bar
    Cooking: 54 recipe(s), 54 with a spell id, 54 with an item id

**Every recipe carries both, and the item id is the product** rather than the recipe. This was
the open one: that client answers with recipe ids and has to be asked separately what each one
makes, the call was written but had never been seen answering, and if it had come back empty
then *Smelt Copper* would not be found by hovering a Copper Bar - the crafted item being where
most people ask the question, not the pattern.

Not only smelting: Cooking answers the same way, 54 for 54, so it is the client and not one
window. Fishing, Skinning and First Aid show zero recipes because their windows had not been
opened, which is §2.2 and not a fault.

### Charges on an item, and the Chronoboon Displacer, measured 2026-08-30

**A container slot carries no charges.** `C_Container.GetContainerItemInfo(0, 1)` on Mists,
with a Lesser Mana Oil in the slot, returns exactly these fields:

    itemName, hasLoot, hyperlink, iconFileID, hasNoValue, isLocked, itemID,
    isBound, stackCount, isFiltered, isReadable, quality

`stackCount` is **1**, not the charge count, and there is no charges field of any name. So the
remaining charges on an oil are not available to the bag scanner at all.

**The maximum is static and wago has it.** `ItemEffect` carries a `Charges` column:
`Lesser Mana Oil` (20747) and `Wizard Oil` (20749) are both `-5`, negative being the "spends a
charge" convention. That is how many it *starts* with and says nothing about how many are left.

**The remaining count exists only in the tooltip**, behind `ITEM_SPELL_CHARGES`, which on an
English client is `%d |4Charge:Charges;`.

#### Reading it, measured on Era 2026-08-30

**`C_TooltipInfo` does not exist on Era.** The structured reader is not available there, so the
old scanning tooltip is the only route on that client. Unmeasured on Mists, which is a modern
engine and may well have it.

**A scanning tooltip works, and does not need to be shown.** Created once as
`CreateFrame("GameTooltip", <name>, nil, "GameTooltipTemplate")`, given `SetOwner(UIParent,
"ANCHOR_NONE")` and then `SetBagItem(bag, slot)`, it answers `NumLines()` immediately and its
lines are readable as the globals `<name>TextLeft<i>`. A Lesser Mana Oil in the backpack:

    lines 5
    1  Lesser Mana Oil
    2  Requires Level 40
    3  Use: While applied to target weapon it restores 8 mana to the caster every 5
       seconds.  Lasts for 30 minutes. (1 Sec Cooldown)
    4  5 Charges
    5  <Made by Nervina>

**Charges are a line of their own**, matching `ITEM_SPELL_CHARGES` exactly. **No line carried
any right-hand text**, so `<name>TextRight<i>` is empty throughout for this item.

The pattern has to be built from the global rather than written out, and in three steps: escape
the magic characters, turn the escaped `%d` into a capture, and replace the whole
`|4singular:plural;` run with a wildcard - the rendered text contains one of the two words and
none of the markup. For English that yields `^(%d+) .+$`, which matches line 4 and none of the
others. Reading it out is §2.1-clean: what is stored is an integer.

Line 5 is worth noting in passing: the crafter's name is in the tooltip too, and it is a name.

**The guild bank has its own setter, and it works.** Measured on Burning Crusade with a guild
bank open - Era has none at all, so it is the client for this question:

    type(tooltip.SetGuildBankItem)  ->  function

    SetGuildBankItem(1, 1)  ->  lines 4
    1  Minor Wizard Oil
    2  Requires Level 5
    3  Use: While applied to target weapon it increases spell damage by up to 8.
       Lasts for 1 hour. (1 Sec Cooldown)
    4  5 Charges

Four lines rather than the bag item's five - no *Made by* line on this one - and the charge
count on a line of its own exactly as in a bag.

**A link cannot answer this.** Everything else in the guild bank scanner reaches a slot by
`GetGuildBankItemLink`, and a link describes the *item*: reading a charge off it through
`SetHyperlink` would give the maximum and file a full oil for one with a single use left.
`SetGuildBankItem` is the only setter that describes the instance in the vault.

**First sight of an unfamiliar item costs a second visit.** The tooltip is empty until the
client has the item, and the scan asks again when it learns - but `ScanGuildBank` can only read
a vault that is still open, since every link call answers nil once the window shuts. So an item
this client has never seen before shows no charge until the tab is opened again. Measured live
on Burning Crusade: correct on the second open, without anything else being done.

Not a fault and not fixable from here: nothing can read a vault nobody is standing at. It is
written down because "I had to reopen it" is the sort of thing that otherwise becomes folklore
about the addon being unreliable.

**The Chronoboon Displacer's charged state is a different item id.** `ItemSparse` on Era:

| id | name | stacks to | spell | category cooldown |
|---|---|---|---|---|
| 184937 | Chronoboon Displacer | 10 | 349858 | 1 hour |
| 184938 | **Supercharged** Chronoboon Displacer | 1 | 349863 | none |
| 212160 | Chronoboon Displacer | 10 | 1223679 | 5 minutes |

**All three clients know it**, which was asked rather than assumed:

| build | 184937 | 184938 | 212160 |
|---|---|---|---|
| Era `1.15.9.69109` | yes, stacks to 10 | yes | yes |
| Burning Crusade `2.5.6.69110` | yes, stacks to 10 | yes | yes |
| Mists `5.5.4.69078` | yes, **stacks to 5** | yes | **absent** |

So the pair that matters - 184937 empty, 184938 charged - is the same on all three and needs no
branch. Two things differ and neither is a detail: the same id stacks to ten on the older
clients and to five on Mists, and the third id is not in the Mists build at all.

**Being in `ItemSparse` is not the same as being obtainable.** These are the tables the client
ships with, and a client can carry an item nobody can get. Whether the Chronoboon is a live
mechanic on each of the three is a question for the game and not for this file - what is settled
here is that a bag holding 184938 means the same thing wherever it is found.

So *"which of my characters has a boon stored"* is answerable **by id, today, with nothing
new**: a bag holding 184938 is a character with one banked. Family already records bag contents
by id, so the fact is on disk already and only wants surfacing.

*Which* buffs are inside is **not in the item's tooltip**, measured on a French Era client with
a charged one in the bag:

    lines 4
    1  Déplaceur de chronochance surchargé
    2  Lié
    3  Unique
    4  Utiliser : Restaure tous vos effets mondiaux suspendus.

Four lines, no right-hand text on any of them, and not one names a buff or a duration. So the
route that answers charges does not answer this: the scanning tooltip reads the item perfectly
well and the item does not say.

**One thing that is not ruled out.** These lines came from a tooltip that was never shown, and
some tooltip content is added by handlers that run on the visible one. Whether the tooltip a
player actually sees carries more than these four lines is a separate question and is not
settled here - if it does, the contents exist and are being missed rather than absent.

**A charged Chronoboon is also an aura on the player**, measured on the same client:

    1  Armure du mage                     ... 22783  (Magic, 1800s)
    2  Déplaceur de chronochance surchargé ... 349981 (no type, duration 0, expires 0)
    3  Intelligence des arcanes           ... 10157  (Magic, 1800s)

So the fact *"this character has buffs banked"* is available twice over - as item 184938 in a
bag and as spell 349981 on the player - and the aura carries **no duration**: 0 and 0, a
permanent aura, so the residual time of what is inside is not there either.

**`UnitBuff`'s tenth return is the spell id**, measured rather than counted off a signature:
22783 for Mage Armour, 349981 for the Chronoboon, 10157 for Arcane Intellect, each in position
ten of the same dump. That matters because a spell id is §2.1-clean where a name is not.

**Reversed the same day, and the answer is yes.** The table below is what each route answered.
The row that matters is the last one, and it is the same row as the fourth: it was **misread**,
not unmeasured.

| route | what came back |
|---|---|
| the item's own tooltip (184938) | 4 lines, no buff among them |
| the player's auras, walked | only the Chronoboon's own; the banked ones are not auras |
| `GetSpellDescription(349981)`, after `RequestLoadSpellData` | `loaded 349981 true`, **length 0** |
| `GetSpellDescription` on the two item spells | 117 and 38 characters, and the wrong text |
| a private tooltip, `SetUnitBuff`, **line 2 read whole** | **162 characters, the buffs among them** |
| the real `GameTooltip`, `SetUnitBuff`, line 2 read whole | the same 162 characters |

**`NumLines()` counts tooltip lines, not text lines.** That single sentence is the whole of the
error. A Chronoboon aura's tooltip is **two** tooltip lines, and the second of them is one string
of 162 characters containing eight rows separated by `\r\n`. The first version of this entry read
`2` and wrote *"2 lines - title, `World effects suspended:`"*, having looked only at the first
row of a multi-row string, and every conclusion after that followed from the word "line" meaning
two different things in the same sentence.

**The string, row by row, with each row's own byte length** - `enUS` Era, one buff stored:

    162
    #24[World effects suspended:]
    #66[  Rallying Cry of the Dragonslayer (120m)]
    #58[While a world effect is suspended, you cannot benefit from]

24 + 66 + 58 = 148, and seven `\r\n` pairs make 162. Nothing here is inferred by subtraction.

**A buff row is 66 bytes and reads as 41.** The other 25 are escapes, read out as bytes because
every probe that typed a literal `|` came back with a false negative - the chat edit box doubles
it, so `s:find("|", 1, true)` searches for `||`. See L-035. The row is:

     |T134153:24|t |cffffffffRallying Cry of the Dragonslayer (120m)|r

    32                              space
    124 84 49 51 52 49 53 51 58 50 52 124 116   |T134153:24|t   icon escape, fileID, 24px
    32                              space
    124 99 102 102 102 102 102 102 102 102      |cffffffff      white
    82 97 108 108 121 ...           Rallying Cry of the Dragonslayer (120m)
    124 114                         |r

So a parser must strip `|T...|t`, `|c%x%x%x%x%x%x%x%x` and `|r` before it reads anything, and
the leading and trailing space besides.

**A private tooltip reads it.** `FPTTextLeft2` on a `GameTooltipTemplate` frame that was never
shown returns the same 162 characters as `GameTooltipTextLeft2` does, byte for byte. So this is
readable through the scanner tooltip Family already owns for oils, and nothing has to touch the
tooltip a player is looking at.

**The aura is found by id, never by index.** `UnitBuff`'s tenth return is the spell id, and
349981 is the one to look for; it was at index 1 in the dump above and that is luck, not a rule.

**What a row looks like, and what a parser may lean on.** The header and the closing sentence are
localised - the same aura on a French client reads `Deplaceur de chronochance surcharge` - so
neither is a landmark. What is stable is the shape: a stored buff is a row ending in a
parenthesised duration, and neither the header nor the footer ends that way. Blank rows are real
and are dropped.

**The twelve buffs a Chronoboon can hold, with their ids and icons**, taken from wago's
`SpellName` and `SpellMisc` at the Era build pinned in section 3. The names came from Wowhead's
render of the conditional block and were used only as search terms; every id and every icon below
is the client's own table:

| buff | spell | icon |
|---|---|---|
| Fengus' Ferocity | 22817 | 136109 |
| Mol'dar's Moxie | 22818 | 136054 |
| Slip'kik's Savvy | 22820 | 135930 |
| Rallying Cry of the Dragonslayer | 22888 | 134153 |
| Warchief's Blessing | 16609 | 135759 |
| Spirit of Zandalar | 24425 | 132107 |
| Songflower Serenade | 15366 | 135934 |
| Sayge's Dark Fortune, eight of them | 23735, 23736, 23737, 23738, 23766, 23767, 23768, 23769 | 134334 |
| Boon of Blackfathom | 430947 | 236403 |
| Spark of Inspiration | 438536 | 236424 |
| Fervor of the Temple Explorer | 446695 | 236368 |
| Might of Stormwind | 460939 | 135763 |

**134153 is Rallying Cry's icon in the client's table and 134153 is what the tooltip handed
back**, which is what makes this a confirmation rather than a correspondence: the icon in the
escape is the spell's own.

**Twelve distinct icons, no collision** - checked rather than assumed, since the whole route rests
on it. The single merge is Sayge's Dark Fortune: eight fortunes, one icon, so the icon says *a*
Sayge's and not which one. That is the price of not putting a localised name on disk.

**Each buff has a second id** in the `355xxx` range for the vanilla ones and `43xxxx`/`46xxxx` for
the Season of Discovery ones - `355363` beside `22888`, `431111` beside `430947` - and the pair
always shares an icon. Which of the two the tooltip is built from has not been measured and does
not need to be, because the icon is the same either way. That is the second reason the icon is the
key and the spell id is not.

**Four of the twelve are Season of Discovery**, and this was asked of all three pinned builds
rather than reasoned about from what Season of Discovery is:

| | Era | Burning Crusade | Mists |
|---|---|---|---|
| the eight vanilla buffs | yes | yes | yes |
| Boon of Blackfathom, Spark of Inspiration, Fervor of the Temple Explorer, Might of Stormwind | yes | absent | absent |

A generator that treats a missing id as a bad name would be wrong about exactly those four.

**The icon is the same fileID on every build it exists on** - 134153 is Rallying Cry on all
three, and so for each of the eight - so the key needs no branch and no per-build table, which is
the standard `ChargedItems.lua` was held to and the reason a union works there too.

**Two things here are inferred and not measured**, and are marked so rather than written as fact:
that two stored buffs give two such rows in the same string, and what order they come in. One
sample is one buff. The parser is built to take any number of rows in any order precisely so that
neither guess is load-bearing - if both are wrong, it reads what is there anyway.

**What this still costs.** A row is a **name** and a duration, which is the one shape §2.1
refuses: `Rallying Cry of the Dragonslayer` is the enUS string and nothing else. Storing it whole
would put a locale on disk and answer wrongly for anyone who changes clients. See the decision on
how the name is turned back into a spell id before it is recorded.

**Two traps, and this entry exists mostly for them.** A screenshot proves nothing about what an
addon can read - the Wowhead render that reopened this was right about the *shape* and could not
have settled the *access*. And an empty answer is not the same as an unloaded one:
`RequestLoadSpellData` and `SPELL_DATA_LOAD_RESULT` are how that was told apart for
`GetSpellDescription`, which really is empty and really is loaded. That route stays closed; it is
simply not the only route.

### Which spell a recipe item teaches, measured 2026-09-01

Who already knows a recipe was decided by matching the item's name against the names in a
member's recipe list. For enchanting those never agree, because the trade skill window
abbreviates: a French client lists `Ench. de bottes (Agilité supérieure)` and names the formula
`Formule : Enchantement de bottes (Agilité supérieure)`. The suffix test fails, and an
enchanter who has known the recipe for a year is offered it as one to learn. Reported from
play, with `/family recipes` showing all 132 enchanting recipes carrying a spell id and **no**
item id.

The ids were on both sides all along. A recipe item's spell teaches another, and the taught one
is the id the window hands back:

    ItemEffect.ParentItemID  16245  Formula: Enchant Boots - Greater Agility
      -> ItemEffect.SpellID  20080
      -> SpellEffect Effect 36 (learn spell), EffectTriggerSpell 20023
                             20023  the enchant, which is what the recipe list records

**Two shapes, and only one of them was handled at first.** Classic Era uses the trigger form
above. On Burning Crusade and Mists a recipe item carries *two* `ItemEffect` rows - a generic
spell 483 with effect 36 and no trigger, and the craft spell itself:

    728  Recipe: Westfall Stew   spells 483 and 2543
         483   effect 36, trigger 0
         2543  effect 24, creates item 733

Reading only the trigger form gave **1008 items on Era and none at all on the other two**, which
is what a generator quietly answering nothing looks like. The rule is: the row's own spell where
a profession teaches it, or the trigger of an effect-36 row where a profession teaches that.

| build | recipe items |
|---|---|
| Classic Era | 1008 |
| Burning Crusade | 1480 |
| Mists | 3346 |

**Per expansion, because they disagree.** Item 23133 teaches 28903 on Mists and 28906 on
Burning Crusade. A union would assert one build's answer on another - the same fault the
cooldown tables were corrected for twice on the same day.

Only where the taught spell is one a profession teaches, which keeps out mounts, riding and
everything else that also learns a spell from an item.

#### And what that spell makes — the second lane, measured 2026-08-31

The spell lane above answers for enchanting and for nothing else on Classic Era, because **the
two windows on that client carry opposite halves of the join**. Measured, and already on this
page: a trade skill record there holds an item id on every recipe and a spell id on none, while
the Craft frame beside it holds the enchant's spell and no item at all.

So the pattern under the cursor has to resolve to *both*: the spell it teaches, and the item
that spell makes. `SpellEffect` effect 24 (CREATE_ITEM) with `EffectItemType` is the second
step, read off the same rows the first step already walks.

    ItemEffect.ParentItemID  2881   Plans: Runed Copper Breastplate
      -> SpellEffect Effect 36, EffectTriggerSpell 2667   the recipe
      -> SpellEffect Effect 24, EffectItemType     2864   Runed Copper Breastplate

| build | recipe items | of them naming what they make |
|---|---|---|
| Classic Era | 1008 | 908 |
| Burning Crusade | 1480 | 1337 |
| Mists | 3346 | 2604 |

**The hundred Era items with no product are not a gap.** Of them, 96 are enchanting — which is
what the spell lane is for — and the remaining four are the Tinker schematics, which apply an
effect to an item and create nothing, the same shape as an enchant on a client that files them
under Engineering. Between the two lanes, every Era recipe item but those four is matched by an
id, and the name test is what is left for them.

**No spell in any of the three builds makes two different items**, checked before the generator
was allowed to write a product at all. It refuses rather than picking one, because a wrong
product id is not a miss - it is another recipe's answer.

### Which recipes have a cooldown, measured 2026-09-01

`GetTradeSkillCooldown` answers with the time remaining and answers **nothing** when there is
none, so a transmute that is ready is indistinguishable from a bandage. Family learned it by
watching, which is honest and slow: a character had to be caught mid-transmute once before
anything would say they had a cooldown at all.

`SpellCooldowns` says so outright:

| spell | field | value |
|---|---|---|
| Mooncloth (18560) | `RecoveryTime` | 96h |
| Transmute: Arcanite (17187) | `CategoryRecoveryTime` | 48h |
| Transmute: Iron to Gold (11479) | `CategoryRecoveryTime` | 24h |

`CategoryRecoveryTime` is the shared timer and `RecoveryTime` the recipe's own, which is the
same distinction players describe as *all the transmutes share one cooldown*.

**And that distinction is carried through into the table, since 2026-09-06**, as a third lane
`shared` listing the skill lines whose timed recipes sit on a category timer. Family used to
infer it by watching - recipes of one profession carrying the same `readyAt` are on one timer -
which is sound while they count down and is no evidence at all once they are ready, when every
ready recipe looks like every other. So an alchemist Family had recorded one transmute of had
that transmute's name put over a column covering all of them.

| build | professions sharing a timer |
|---|---|
| Classic Era | Alchemy |
| Burning Crusade | Alchemy, Enchanting |
| Mists | Enchanting |

Per skill line rather than per recipe, which is the granularity the panel groups at. And per
expansion like the rest of the table, which is what makes it worth reading rather than writing
by hand: Enchanting's Void Sphere and Prismatic Sphere are two names for one timer on the builds
that have them and neither exists on Era, so a rule written about alchemy alone would have been
wrong about the pair actually on screen.

**Per expansion, and this is not a nicety.** The same spell differs on every build, and on the
newest usually has none at all:

| spell | Era | Burning Crusade | Mists |
|---|---|---|---|
| Transmute: Mithril to Truesilver | 48h | 20h | 1 second |
| Transmute: Arcanite | 48h | absent | absent |
| Void Sphere | absent | 48h | 48h |

A union across builds would tell a Mists alchemist about a two-day cooldown that does not
exist. So the table is keyed by expansion and read through `Family.Capabilities.expansion`,
exactly as `TalentSpells.lua` is.

**Keyed by spell and by what the recipe makes.** A recipe on Classic Era usually has no spell
id: measured on a French client, all 111 alchemy recipes came back with an item id and no spell
among them. A table keyed only by spell would miss precisely the case it exists for. The item
is reached by the chain `made-by-item.py` already uses - `SpellEffect` with effect 24 names
what a spell creates.

**A recipe makes something, and that is the filter.** The first version took every profession
spell over an hour, which let in engineering trinkets: a Mechanical Dragonling's *summon* is
filed under Engineering and has an hour's use cooldown, and would have been drawn on the
Crafting panel as a crafting cooldown. Requiring the spell to create an item removes them, and
the hour floor then only has to exclude the vanilla transmutes on Mists, which are one second
because that expansion removed them.

| build | recipes with a cooldown | of them, reachable by what they make |
|---|---|---|
| Classic Era | 13 | 11 |
| Burning Crusade | 29 | 24 |
| Mists | 3 | 3 |

**The item lane is keyed by profession as well, measured 2026-09-03.** What a recipe makes does
not say who made it, and on the two builds that matter the same bar is made twice:

| item | one way | the other |
|---|---|---|
| Gold Bar 3577 | Mining, *Smelt Gold* 3308, **no cooldown** | Alchemy, *Transmute: Iron to Gold* 11479, 24h |
| Truesilver Bar 6037 | Mining, *Smelt Truesilver* 10098, **no cooldown** | Alchemy, *Mithril to Truesilver* 11480, 48h |

Keyed by item alone, the alchemist's cooldown was handed to the miner - and mining has no
crafting cooldown at all on Classic Era, so every miner who could smelt gold grew a Mining
column on the Crafting panel reading *ready* for ever. Reported from play from a French Era
client, beside a real transmute column. So the skill line that teaches the spell travels with
the number, and a match has to agree about the profession as well as the item. A spell id needs
no such care: it names one recipe of one profession.

**What is still learned by watching.** Anything the table has never heard of - and a nil here is
not a claim that there is no cooldown, only that this table does not know of one.

#### The generated table checked against a live client, measured 2026-08-31

Reported from play: a Burning Crusade tailor who knows Mooncloth was not on the Crafting panel,
where the same character on Classic Era would have been. The table says Mooncloth has no
cooldown on that build, and the client was asked whether it agrees. Burning Crusade
Anniversary 2.5.6, spell 18560:

```
GetSpellBaseCooldown(18560)   0
SetSpellByID(18560)           4 lines - title, reagents, flavour text, "Mooncloth"
                              no cooldown on any of them, left or right
```

So the client and the build's `SpellCooldowns` agree, and the panel was right: **the cooldown
moved to the tier above.** Primal Mooncloth (26751), Spellcloth (31373) and Shadowcloth (36686)
each carry 92h on that build, and plain Mooncloth carries nothing, where Classic Era gives
18560 a `RecoveryTime` of 96h.

This is the second time an Era habit has been read as a Burning Crusade bug - the first was
Mote-to-Primal, in the other direction - and it is the argument for the per-expansion tables
stated as a measurement rather than as a principle.

### Binding: what the item says, and what the instance says, measured 2026-09-11

Read on Mists with `/family bind`, against a character's own bags and worn gear. Every one of the
game's binding strings is present - `ITEM_SOULBOUND`, `ITEM_BIND_ON_EQUIP`, `ITEM_BIND_ON_PICKUP`,
`ITEM_BIND_ON_USE`, `ITEM_ACCOUNTBOUND`, `ITEM_BIND_QUEST` - and `C_Item.IsBound` exists on that
build as a function.

**`GetItemInfo`'s fourteenth return is the bind type**, and the mapping is not inferred from a
name: it is the fourteenth return held against what each item's own tooltip said, over ten items
of three kinds.

| return 14 | items read | their tooltip said |
|---|---|---|
| **1** | 6948 Hearthstone, 63216, 63211 | `soulbound` |
| **2** | 10009, 7519, 10018, 10003, 7052 | `equip` |
| **4** | 63028, 7667 | `quest` |

So 1 is bind-on-pickup, 2 is bind-on-equip and 4 is a quest item, on that build. The rest of the
row is the ordinary signature and was read the same way: 9 is the equip location, 10 the texture
file id, 11 the sell price, 12 and 13 the class and subclass, 15 the expansion.

**What the item cannot say is whether this one has bound.** Return 14 is a property of the kind: a
bind-on-equip sword reads 2 whether it is in a bag or on somebody's back. The instance is only in
its own tooltip, which is what `Family:BindingIn` and `Family:BindingWorn` read - whole lines
compared against the game's own words, so a German client needs no German here.

**And equipped does not mean bound.** The clearest single row of the reading:

    worn slot 4, item 4334: nil

A shirt, worn, and its tooltip says nothing about binding at all - so it never binds, and it can
be sold at auction while being worn. Any rule of the form *what is equipped is soulbound* is
wrong, and it is wrong on exactly the items a shortcut would have been written for.

**And the quiet rows, read on Classic Era the same day**, which is the half the first writing of
the probe filtered out and the half that decides what this costs:

| item | return 14 | its tooltip |
|---|---|---|
| 2901 mining pick, 6365 fishing pole, 5956 blacksmith hammer, 6533 fish attractor | **0** | nothing at all |
| 5872, a bind-on-use thing already used | **3** | `soulbound` |

So **0 is *never binds***, and **3 is bind-on-use** - measured on Burning Crusade from an unused
one and on Era from a used one, which is also the row that says 3 needs the instance exactly as 2
does. The full mapping, over three clients and some thirty items:

    0 never   1 on pickup   2 on equip   3 on use   4 quest item

**Which makes the instance cheap.** Only 2 and 3 can be either bound or not, so only those need a
tooltip; 1 and 4 are bound wherever they sit and 0 never is. A bag of cloth, a pick and a pole are
settled by one call apiece. That is the difference between reading a handful of slots a character
and reading every slot of every bag, and it is why this was measured before anything was built.

`C_Item.IsBound` exists as a function on all three builds and is not used: presence is not
behaviour on these clients, and the tooltip answers in the client's own words without a second
reading to justify it.

### What the server says when an auction is bought out, measured 2026-08-31

Buying something out sends it by mail, exactly as posting to an alt does, so it belongs in the
same *in the post* count. The question was which event says it went through. Measured on a
French Classic Era client, buying one item out, with a frame listening to everything:

    ... many AUCTION_ITEM_LIST_UPDATE while browsing ...
    CHAT_MSG_SYSTEM   Vous avez gagné les enchères pour Cristal des arcanes
    AUCTION_ITEM_LIST_UPDATE
    CHAT_MSG_SYSTEM   Offre acceptée.
    AUCTION_BIDDER_LIST_UPDATE

**Two system messages, and only the first one means an item is on its way.** They are the
client's own globals:

| global | value on that client | says |
|---|---|---|
| `ERR_AUCTION_WON_S` | `Vous avez gagné les enchères pour %s` | this auction is yours |
| `ERR_AUCTION_BID_PLACED` | `Offre acceptée.` | a bid was accepted, and nothing more |
| `ERR_AUCTION_OUTBID_S` | `Vous n'êtes plus le plus offrant pour %s.` | you lost it |

#### The older house prices the whole stack, and the arithmetic says so before anybody is asked

Read on Classic Era 2026-09-10, one auction just posted, through `GetAuctionItemInfo("owner", 1)`:

    item 4611    quantity 3    minBid 28463    buyout 29961

`29961 / 3` is 9987 exactly, which settles nothing on its own. **`28463 / 3` is 9487.666**, and a
price of one cannot be a fraction of a copper because nobody can type one - so that field is a
stack total, and the buyout beside it is the same kind of field. Confirmed by the person who typed
it: 2g99s61c was for all three. So Family's older reader has always been right to treat the buyout
as the whole auction, and the browse prices are right to divide.

**Which turns up a fault of Family's own.** The first browse reader recorded a price only where the
stack divided exactly, which on a house where a human types the total throws most of them away in
silence - seven of something at five gold is 71.43 copper each, and that was recorded as nothing at
all. It rounds down now. Losing a fraction of a copper to a division is arithmetic; losing the
auction is losing the reading. A stack so large that one of them comes to nought is still refused,
because nought is not a price anybody paid.

#### A sold auction answers with no quantity

Read on Burning Crusade 2026-09-10, thirteen rows on one character through the owner list:

    item 818     quantity 0   minBid 0        buyout 1497     <- Tigerseye, Sold
    item 1210    quantity 0   minBid 0        buyout 2536     <- Shadowgem, Sold
    item 2770    quantity 0   minBid 0        buyout 1638     <- Copper Ore, Sold
    item 24582   quantity 1   minBid 342000   buyout 359999   <- still up
    ... ten of those ...

The three the window labels **Sold** answer a quantity of nought and a minimum bid of nought, and
the buyout carries what is on its way to the mailbox - 14s97c, 25s36c and 16s38c, which is what
the window draws beside them as *Incoming Amount*. Confirmed by Alberto looking at the same
screen: sold, waiting to be delivered. All ten live rows answer a real quantity.

**They were already being left out, and for the wrong reason.** The client gives a sold auction no
time left either, so it read as expired and `Live` dropped it - the totals were right by accident.
A client that answered with a real bucket there would have folded money already earned into what
is still for sale, and nothing on any panel would have said so. The quantity is what decides now.

The panel's own arithmetic was held against that window at the same time: ten auctions,
**158g57s88c** of bids and **166g92s45c** of buyouts, to the copper, with the three sold rows out
of both.

The same probe answered one more thing: **Era has no `C_AuctionHouse` at all** - `newer auction
house: false` - and 25 `AUCTION_ITEM_LIST_UPDATE` firings across a session. Which is why neither
route needs a gate: on that client the newer one has nothing to read from, and on Mists the older
one has nothing to read from, and each is silent rather than wrong.

**And it is the same event the prices come off.** `AUCTION_ITEM_LIST_UPDATE` fires many times
while somebody searches, as the trace above shows, so what is on sale can be read from the list
the player is already looking at - `GetNumAuctionItems("list")`, `GetAuctionItemLink` for the id,
and `GetAuctionItemInfo` for the row, whose third value is the stack and whose tenth is the
buyout, which is where the owner reader takes them from. Family sends **no query**: nothing here
calls `QueryAuctionItems`, and the whole query side of the auction house has never been read
anywhere in this repository. `/family ah` is what will settle that, on all three clients, before
anything is built on it.

#### What the query side answers, `/family ah`

Burning Crusade Anniversary, 2026-09-10, standing at an auction house with a search on screen:

    GetNumAuctionItems  GetAuctionItemInfo  GetAuctionItemLink  QueryAuctionItems
    CanSendAuctionQuery  SortAuctionItems  GetAuctionItemSubClasses  GetSelectedAuctionItem
        all eight: function

    a query would be accepted now: true
    rows on show in the browse list: 50
    prices remembered for this realm and side: 24, oldest 2m ago, newest 1m ago

So the whole query side exists on that build and `CanSendAuctionQuery` answers, which is the call
a safe scan has to be gated on. **Fifty rows is one page**, so a full read is a page walk rather
than one call - what `getAll` does on these builds is a separate question and is not asked here.
The last line is the passive reader working in play: twenty-four prices off an ordinary search,
with nothing queried for.

Classic Era, the same day, immediately after a search:

    all eight: function
    a query would be accepted now: true
    rows on show in the browse list: 0
    prices remembered for this realm and side: 57, oldest just now, newest just now

**The same eight calls, and the same answer from `CanSendAuctionQuery`** - so the query side does
not differ between those two builds in any way this probe can see. Nought rows is the browse list
after it has been cleared, not a client that will not answer: fifty-seven prices had just been
taken off it.

**Mists of Pandaria has the newer auction house, and the old calls there are shells.** Read the
same day, standing at an auction house with the prices switched on:

    all eight: function          a query would be accepted now: true
    list 0    bidder 0    owner 0
    list updates heard since login: 0, last one showed nil
    newer auction house: GetBrowseResults, SearchForFavorites, GetNumReplicateItems,
                         QueryOwnedAuctions, SendBrowseQuery

So `GetNumAuctionItems` and the seven beside it **exist and answer nothing**, all three selectors
alike, and `AUCTION_ITEM_LIST_UPDATE` did not fire once across a session of browsing. Presence is
not behaviour, which is §2.3 stated by measurement: a capability table that asked whether the
symbol was there would have answered *yes* for a build where none of it works.

**This is wider than the prices.** Everything in `Scanners/Auctions.lua` reads those calls,
including the owner list - so *what a member has up for sale*, and the summary columns built on
it, have been silently empty on Mists rather than wrong. Nothing announced it because nought
auctions is what somebody with no auctions has. Backlog 56.

**And the signature is sharper than that**, seen on the Activity set 2026-09-10: the column reads
**not seen**, not nought. `Summary.lua` draws that where `meta.auctionsSeen` is absent, and that
field is written at the end of a scan - so the scan had never *run*, not run and found nothing. It
could not: the only two events that call it are the two that never fire on that build. Which is
also why nobody reported it. *Not seen* is the right answer for a character who has never visited
an auction house, and on Mists it was the answer for all of them.

**What the newer house answers**, read the same day. A search: `GetBrowseResults` holding **500**
rows, `AUCTION_HOUSE_BROWSE_RESULTS_UPDATED` fired once and the other four not at all. One row of
it, printed rather than named from memory:

    containsOwnerItem  false
    itemKey            { battlePetSpeciesID=0, itemID=32902, itemLevel=68, itemSuffix=0 }
    minPrice           1
    totalQuantity      442

**`minPrice` is already the lowest price of one**, across every listing under that key, so this
route divides nothing and takes no minimum of its own - the one place the newer house is simpler
than the old, where fifty rows have to be walked and the least of them taken. A key carries an item
level and a suffix, so two rows can share an id and be different things; Family files under the id,
because the tooltip that will ask knows an id and nothing else, and the cheapest variant therefore
speaks for the plain one.

#### Another addon's full scan, measured 2026-09-12

`/family ah watch` prints every argument of the next `QueryAuctionItems` **whoever sends it**,
which turns out to include other addons on the same machine. Armed on Burning Crusade
Anniversary and then Auctionator's *Full Scan* pressed:

    1  ""      2  nil   3  nil   4  0     5  nil
    6  nil     7  true  8  false 9  nil

Nine arguments, the page fourth as this build has always answered, and the **seventh `true`**.
On this build that position is `getAll` — one request for the entire house, which is what the
fifteen minutes Alberto measured against Family's page walk actually buys, and which is a
different mechanism rather than a faster walk. Family's own walk on the same house is 2.1
seconds a page over 3,563 pages, just over two hours, of which 1.85 seconds a page is the client
refusing to send.

**This is a reading about another addon, taken on one machine.** What it settles is what that
scan sends, not what any addon must send.

It also settles something about Family, and not comfortably: Family replays *the client's last
query*, and the client is whatever last called that function. For as long as this was the last
one, a walk would have replayed `getAll` with the page changed. It now refuses any query
carrying a `true` in an argument it does not change — see `docs/LESSONS.md` L-084.

#### What `CanSendAuctionQuery` answers, and what it does not, measured 2026-09-12

One value, on Burning Crusade Anniversary, in both states that were read:

| standing at an auctioneer | answer |
|---|---|
| browse list holding 50 rows, nothing running | `true`, and nothing after it |
| another addon's whole-house read arriving, 72,704 rows on the list | `false`, and nothing after it |

The probe prints **every** return, so the absence of a second one is a reading rather than a
gap: it was read into a single local before 2026-09-12 and could not have shown one (L-081).

So the client says whether a query would go out **now**, and nothing about the whole-house route
having its own interval. The fifteen minutes another addon holds itself back for does not come
from here. What has **not** been read is this call during that countdown, with no scan running -
so *the arity never changes* is an assumption and is written down as one.

#### Where a whole-house read lands, measured 2026-09-12

The important half. While another addon's full scan was arriving on Burning Crusade, the probe
read the **browse list** - the same list Family already takes prices off, through
`GetNumAuctionItems("list")` and `GetAuctionItemInfo("list", index)`:

    list     72704
    the browse list holds 72704 row(s), of 72704 on sale in all

Not a list private to that addon: the client's own, and both returns grow together as it
arrives. A house Family measured at 178,128 auctions was on its way into the list Family reads.

**The client lags very badly, does not disconnect, and *when* it lags is the open question.**
Reported from play the same evening, on the same 178,128-auction house. The first deliberate
reading of it here - the only other was `getAll` sent by accident on 2026-09-10, seen from the
outside as ten seconds of silence and a client crawling a minute later (L-071).

Read more closely a few minutes on, and the shape is not what the first note here said. That note
read *the delivery costs this, not reading the list afterwards*, which was a cause fitted to a
correlation and is withdrawn. What was actually watched: the other addon shows a percentage and
no scrolling window; from nothing to 99% took about three minutes **with little or no lag**, and
it then sat at **99% for about another three minutes, lagging hard**.

Two readings fit and they point opposite ways:

- the last of it is still arriving, and the percentage is that addon's own estimate - then the
  cost is delivery, and anything reading the finished list pays none of it;
- it is all there and something is walking 178,128 rows in one pass - then the cost is the
  **reading**, and anything else reading that list pays it too.

**What tells them apart**, and it costs nothing: `/family ah` twice during the stall, ten seconds
apart, and compare the `list` count. Still climbing is the first; standing still at the full total
is the second. Unread as of this writing.

**And `AUCTION_ITEM_LIST_UPDATE` had not fired once.** The probe's counter stood at 43 with
72,704 rows already there, last one showing 50 - so the list fills in silence, and whether
anything is said at the end is unread.

#### What the whole scan actually did, read afterwards 2026-09-12

The probe again once the client was calm, with that addon's own countdown running:

| | before | after |
|---|---|---|
| `list updates heard since login` | 43 | **5788** |
| `prices remembered for this realm and side` | 4533 | **5906** |
| `list`, auction window freshly reopened | 50 | **0** |
| `a query would be accepted now` | `true` | `true`, and nothing after it |

Four things follow, and none of them needed a query of Family's own.

**`AUCTION_ITEM_LIST_UPDATE` fires, and fires enormously.** 5,745 of them across one scan, where
the reading taken partway through - 72,704 rows on the list, counter still at 43 - had suggested
the list filled in silence. It does not; the silence was the middle of it. So Family can notice a
full list without being told to look.

**Family already took 1,373 prices from it, with no code for the purpose.** The passive reader
reads the browse list whenever that event fires, and the browse list was the whole house. That
addon reported 15,899 distinct items; Family holds 5,906 for this realm and side now.

**A full list does not survive the window closing.** Reopened, `list` reads 0. Whatever is going
to be read has to be read while it is there.

~~**The client says an ordinary query would be accepted, in one value, while that addon counts
down three and a half minutes**, so the interval is that addon's own.~~ **Wrong, and corrected
below.** That reading was taken with only the first of `CanSendAuctionQuery`'s answers on show.

Timing, from play: about three minutes to 99% with little lag, then about three more sitting at
99% lagging hard, so roughly six minutes for the scan against the fifteen the countdown runs for.
The fifteen minutes this was first compared against is mostly the wait, not the read.

**And most of that stall was Family's, measured by taking it away.** `ReadPrices` walked
`1..count` of the browse list every time that event fired, with no cap - fifty rows on an
ordinary search, up to 178,128 rows here, thousands of times. Read in slices instead, the same
scan on the same client and a house of the same size (177,377 against 178,128) stalled at 99%
for **under thirty seconds instead of about three minutes**. Two runs on one machine, with
Family's own build as the only deliberate difference.

Two more readings came with the second run, and both correct earlier notes here:

- **`CanSendAuctionQuery` gives two values after all**, on this same build and client. The note
  above records a single value and *the arity never changes* as an assumption; the assumption is
  contradicted, and so is the conclusion that rested on it. Read across three states:

  | standing at an auctioneer | first | second |
  |---|---|---|
  | nothing running | `true` | `true` |
  | a whole-house read arriving | `false` | `false` |
  | that addon counting down 48 seconds | **`true`** | **`false`** |

  The two answers **diverge in the third state and only there**: an ordinary query would be
  accepted while the second says no. So the second answer tracks the whole-house route, and the
  quarter of an hour is the **client's**, reported by that addon rather than invented by it -
  the opposite of what the struck-through line above concluded from the first answer alone.

  What the second return is *called* is not established here and is not guessed at; what is
  measured is that it says no exactly while a whole-house read is not available. Family sends no
  such read, so this changes nothing it does - it closes a question rather than opening a door.
- **The event does not fire while the list is filling.** 156,800 rows on the list with the
  counter still at nought; then 30,148 firings once it was done, and 74,483 a little later. So a
  reader hung off that event sees nothing for the whole delivery and then everything at once.

#### What a full read still needs, and why it is not built yet

Written 2026-09-10, when slice 3 was picked up. Three things are still unmeasured, and the first
of them is the one that stops everything else.

**1. The shape of `QueryAuctionItems`.** Nothing in this repository has ever called it, and a C
function cannot be asked what arguments it takes. The order is not the same on every one of these
builds, and `page` - the only argument a walk has to vary - sits in a different place depending on
which order it is. Two candidate layouts are written into `Scanners/Auctions.lua`, **neither
confirmed here**:

    long    name, minLevel, maxLevel, invType, class, subclass, PAGE, usable, quality, getAll, exact
    short   name, minLevel, maxLevel, PAGE, usable, quality, getAll, exact, filterData

`/family ah query long` and `/family ah query short` send **one** query each, gated on
`CanSendAuctionQuery`, and print what came back on the next list update: how many rows, how many
there are in all, and the first three rows as ids and prices. The layout is typed out in full and a
second query is refused while the first has not answered - see below for why.

**Measured 2026-09-10, on a live Burning Crusade client, and it is the first real reading here.**
The `long` layout was sent and **nothing answered within ten seconds**. The command as first
written then took the *other* layout on the next run, which is the obvious thing to do after
silence - and after that second query the client crawled for minutes. Alberto got a `/reload`
through without a hard kill, so nothing was lost.

What this does **not** say is which layout is wrong, or that either of them caused the crawl: a
server-side throttle after two queries in quick succession would look the same from inside the
game. What it does say is that **the silence is real** - ten seconds with no `AUCTION_ITEM_LIST_UPDATE`
after a query the client said it would accept - and that is itself the measurement. On that build
the passive reader hears that event forty-three times in a session of ordinary searching, so a
query that produces none of it is a query that did not do what it looks like it did.

**Run again the same evening, `long` alone, once: the same silence and no lag at all.** So the
crawl and the silence are two different things, and only the silence is repeatable. One caution on
that reading, and it is against the instruction rather than the client: it was run with the auction
window **closed**, which is what had been asked for, and a query outside an auctioneer session has
nowhere to go. `CanSendAuctionQuery` still answers true there.

#### The signature, measured on Burning Crusade 2026-09-10

Read by hooking the client's own call and pressing Search on an unfiltered Browse tab - empty name,
empty level range, rarity *All*, *Usable Items* unchecked:

    1  ""        5  false
    2  0         6  -1
    3  0         7  false
    4  0         8  false
                 9  nil

**Nine arguments**, and every visible control on that window has one of them: name, minimum level,
maximum level, **page**, usable, quality, `getAll`, exact match, filter data. The page is the
fourth and it is nought-based; rarity *All* is `-1`; the empty level boxes are `0` rather than nil.

**`getAll` is the seventh.** The eleven-argument layout that had been guessed here put `page`
seventh and passed `0` for it - and in Lua `0` is true, so that call asked for the whole house.
That is L-071, and it is why nothing is guessed any more: Family now sends **the client's own last
query with the page changed**, and works out which argument is the page from two of the client's
own queries differing in exactly one numeric place. Era and Mists are not read yet.

#### How big the house is, measured 2026-09-11

The replayed query worked on the first try: page 1 asked for by Family, fifty rows back, and the
second return of `GetNumAuctionItems("list")` - the one nothing here had ever read - said

    the browse list holds 50 row(s), of 180205 on sale in all

**180,205 auctions, fifty to a page: 3,605 pages.** That is the arithmetic entry 55 said would
decide whether an opt-in full read is minutes or an evening, and it is an evening. It is also why
`getAll` exists at all, and why it is still never sent: the whole house in one call is the route
that freezes a client.

So the walk is **clocked by the server** - the next page is asked for because the previous one
arrived, never on a timer, so it runs exactly as fast as the client is being answered and cannot
get ahead of it. `CanSendAuctionQuery` is asked before **every** page rather than only the first,
because it answers about now and this spends an hour in a lot of nows. It stops on the house
closing, on a refusal that does not clear, on a page that does not arrive within thirty seconds,
and on being told to. Everything already read is kept.

#### And none of the above is Mists, measured 2026-09-11

`/family ah watch` was armed on Mists, Search was pressed, and **nothing was ever printed**. That
client does not call `QueryAuctionItems` at all - the old calls there are shells, which this file
already recorded, and this is the same fact from the other end. `/family ah query 1` refused with
*no query of the client's own has been seen this session*, which was true and misleading: on that
build it never will be.

**And its house is a different shape, not just a different call.** The browse list is **one row
per item** with the number on sale beside it - *Northern Spices 3,583*, *Refreshing Spring Water
912* - and the individual auctions appear only when a row is opened. There is no Prev/Next,
because there are no pages: one search answered **500 rows** and the reader took **495 prices out
of them in a single ordinary look**, which is more than a page walk on the older house gets in
fifty queries.

So a full read there is `SendBrowseQuery` with nothing in it, then `RequestMoreBrowseResults` until
`HasFullBrowseResults` says so - three calls whose presence `/family ah` now reports and whose
behaviour has not been read. Until it has, the page walk refuses on that build **and says which
house it is looking at**, rather than reporting a query that will never arrive.

**And the shape of that query is read the same way the older one was**: `/family ah watch` hooks
`C_AuctionHouse.SendBrowseQuery` as well, and prints the table the auction house itself passes when
Search is pressed - a field at a time, one level deep, with a list saying how many are in it. A
table cannot go wrong the way a row of arguments did (L-071), but the field names are exactly as
much hearsay, and one wrong name is a query that searches for something nobody asked about.

The description of it found a fault in its own first writing, worth recording because it is a Lua
trap rather than a WoW one: fetching a value with `t[k] ~= nil and t[k] or fallback` **loses every
value that is `false`**, and `exactMatch` is false far more often than it is true. Looking a key up
again by `tostring(key)` loses every numeric key as well. The check for it went red the first time
it ran.

#### The client asks for us, and that is the reading that costs nothing

Written after the above and it should have come first. **The auction house calls
`QueryAuctionItems` itself on every Search**, with the arguments that are right for that build.
`/family ah watch` hooks it with `hooksecurefunc` - which runs after the real call and takes
nothing from it, the same arrangement the bid watcher already uses - and prints the next one the
client sends, argument by argument, then disarms.

No traffic of ours, no guess at an order, and nothing that can disconnect anybody. The arguments
are read with `select("#", ...)` rather than out of a table, because a nil in the middle **or at
the end** is part of the shape and a table's length loses the last one - the short layout ends in
`filterData`, which is exactly that case.

**The test is not whether rows arrive.** A layout the client accepts can still have queried the
wrong thing, and rows would come back either way. What settles it is **the total held against the
number the auction window is showing on screen**, and the first three rows against what is at the
top of it. That is a comparison a person makes, which is why the command prints and decides
nothing.

**2. How many there are in all.** `GetNumAuctionItems("list")` has a second return and nothing here
had ever read it; `/family ah` now prints both. Fifty rows is one page, so the number of pages is
the second divided by fifty - and a house with twelve thousand things in it is 240 queries, which
is the arithmetic that decides whether an opt-in full scan is minutes or an evening.

**3. How the newer house is paged.** One search answered **500** browse rows on Mists and a house
holds more than five hundred things, so something has to say whether that was all of them.
`/family ah` now reports whether `HasFullBrowseResults`, `RequestMoreBrowseResults`,
`ReplicateItems`, `GetReplicateItemInfo` and `IsThrottledMessageSystemReady` exist on that build.
Presence is not behaviour - that lesson is two sections above this one - so their answers are the
next reading after this one, not a design.

**`getAll` is false in both layouts and is not offered as a choice anywhere.** It is the route that
freezes a client and disconnects people; that it is never sent was decided before a line of this
was written, and the harness holds it rather than a comment.

**Confirmed end to end 2026-09-10**, eleven auctions with stacks from one to a hundred and
fifty-two, the panel's total held against the auction window row by row:

    Goblin Deviled Clams  x12   19s99c each   2g39s88c
    Solid Stone          x152    3s98c each   6g04s96c
    Vermilion Onyx         x1   49g99s82c    49g99s82c
    ... eleven rows ...                      75g80s94c

Which is what the Activity set drew, to the copper. **Not multiplying would have given 62g80s86c**
- thirteen gold out of seventy-five, on a screen where nothing else says what the answer should
be. That is why the question went to the person who typed the prices rather than being settled by
which reading looked more plausible: both did.

**And the owner list does answer there.** Listing one item took `GetNumOwnedAuctions` from nought
to one and fired `OWNED_AUCTIONS_UPDATED` four times, with `COMMODITY_SEARCH_RESULTS_UPDATED`
firing three. Both `GetOwnedAuctionInfo` and `GetOwnedAuctions` are present. So backlog 56 has a
route; what a row of it looks like is the next thing to read, and needs a character with something
actually up for sale.

**The reader working, measured the same day:**

    auctions: 497 price(s) taken from 500 browse result(s)
    prices remembered for this realm and side: 497, oldest just now, newest just now
    AUCTION_HOUSE_SHOW 1     AUCTION_HOUSE_CLOSED 0

Two things settled by that. **The visit events fire on the newer house**, so the rule that starts a
new reading works on all three builds and prices there cannot drift downwards for ever - which was
the open risk when this route was written. And a browse with nothing typed into it answers with the
cap, so one idle look at the auction house on Mists is worth more than a session of searching on
Era: 497 of the 500 carried a usable key and a price, and the three that did not were passed over
rather than guessed at.

**Neither route is gated, and both are registered on every client.** The old one reads a list that
answers nought on Mists; the newer one reads a call Era has not got; each is silent where it does
not apply. Nothing has to decide which auction house this is - which is exactly the decision that
would have been got wrong, since all eight old symbols are present on the build where none of them
work.

**Reported alongside it: Era drew no price lines at all**, while remembering prices perfectly -
and **confirmed the same day to have been the switch**, nothing else. It ships off and `FamilyDB`
is one file per game version, so turning it on for Burning Crusade turns on nothing for Era. `/family ah` now says which way the switch is set, because that is the
question somebody is asking when they run it.

A pattern is built from `ERR_AUCTION_WON_S` the way the oil charge line is built from
`ITEM_SPELL_CHARGES`: escape the wording, turn the escaped `%s` into a wildcard, anchor it at
both ends. Nothing here knows a word of French or of English.

**What this makes unnecessary.** The first design compared the bid against the auction's buyout
price to decide whether it was a buyout - which needs to know where `GetAuctionItemInfo` puts
that price, and it moves between expansions. It is not needed. The bid is remembered whatever
kind it was and nothing is recorded until the server says it was won, so **the server decides
whether it was a buyout**. A buyout somebody beat you to is never confirmed and writes nothing.

**What cannot be covered.** Winning a bid that runs to its end sends the item hours later,
usually while the player is logged out. There is no event and nothing to hook, so only buyouts
- and a bid that happens to close while you stand there, which is the same message - are
reachable.

### Things made by using an item, measured 2026-08-31

Refined Deeprock Salt is on nobody's recipe list. It comes out of a **Salt Shaker**, an item
with a four-day cooldown - so *who can make me one* is really *who owns a shaker, is theirs
ready, and can they use it*. Family answered none of that and showed only who already held some.

**The chain, in the client's own tables**, since no API exposes it:

    ItemEffect.ParentItemID   the item
      -> ItemEffect.SpellID   the spell it casts
      -> SpellEffect where Effect = 24 (create item)
      -> SpellEffect.EffectItemType   what comes out

Item 15846 (Salt Shaker) casts a spell whose effect 24 creates item 15409 (Refined Deeprock
Salt), which is the reported case, resolved by the tables rather than by a hand-written pair.

**Only the makers that make you wait.**

| build | items that create an item | of those, on a cooldown |
|---|---|---|
| Classic Era | 584 | 58 |
| Burning Crusade | 1842 | 61 |
| Mists | 3577 | 131 |

The union of the cooldowned ones is **131 things**. The wider set is noise for this question - a
Staff of Conjuring makes a Conjured Muffin and a Muisek Vessel makes a Muisek - and being told
who owns a Lei of Lilies while hovering a Lily Root answers nothing anybody asked. A cooldown is
what makes an item a thing you go to a particular character for.

**Several items can make one thing**, so each entry is a list. Two `OLDCeremonial Club`s both
make Broken Tools, and refusing that was the generator's first behaviour and was wrong. Nothing
is filtered by name: an `OLD` prefix is a judgement about what matters, encoded in a generator.

**Owning it is not using it**, which is the half that was nearly missed. `ItemSparse` carries
`RequiredSkill` and `RequiredSkillRank`, and for the Salt Shaker they are **165 and 250** -
Leatherworking at 250. A character can hold one and be no use at all. Three of the 131 makers
demand a profession this way, and the table carries the condition beside the join:

    [15409] = { { item = 15846, skill = 165, rank = 250 } },

Reported from play, after the first version of this had already been written on ownership alone.

### Profession specialisations, and what gates a recipe, measured 2026-08-31

A blacksmith is an armoursmith or a weaponsmith and cannot be both; an engineer is gnomish or
goblin. Recipes belonging to a branch cannot be learnt by anybody on another one, ever - so
*can learn it* was a false claim, and no amount of levelling would have made it true.

**Specialisations are not skill lines**, which is the first thing that was tried and the first
thing that failed. `SkillLine.ParentSkillLineID` is empty for every profession on Classic Era
and Burning Crusade; on Mists it names the six cooking ways and nothing else. There is no
child-skill-line relation to walk.

**`SkillLineAbility` does not carry it either.** A Gnomish Death Ray row and a Copper Chain Belt
row are the same in every column that exists:

    ID     SkillLine  Spell   MinSkillLineRank  SupercedesSpell  AcquireMethod  Flags
    6950   202        12759   1                 0                0              0      Gnomish Death Ray
    1632   164        2661    55                0                0              0      Copper Chain Belt

**It is on the item.** `ItemSparse.RequiredAbility` is the spell a character must already know
before the item will teach them anything, and that is the whole relation:

| build | gated recipe items |
|---|---|
| Classic Era | 149 |
| Burning Crusade | 89 |
| Mists | 23 |

The union is **239 items across 5 professions**, and it agrees with what players know: Era has
Blacksmithing, Leatherworking and Engineering; Burning Crusade adds the three Tailoring
branches; on Mists only Gnomish and Goblin Engineer still gate anything, the rest having been
removed from the game.

**`RequiredAbility` is not only specialisations, and this is the trap.** It carries riding
skills - 514 mount items on Mists alone - and battle pet training. So an ability counts only if
it is **itself a spell taught under a primary profession's skill line**, which the client's own
tables answer:

| ability | in `SkillLineAbility` under |
|---|---|
| Armorsmith 9788, Weaponsmith 9787, Master Sword/Hammer/Axesmith | Blacksmithing 164 |
| Dragonscale 10656, Elemental 10658, Tribal 10660 | Leatherworking 165 |
| Gnomish Engineer 20219, Goblin Engineer 20222 | Engineering 202 |
| Journeyman Riding 33391, Battle Pet Training 119467, Potion Master 28675 | **not there at all** on Era |

So the filter is a question rather than a list, and `tools/specialisations.py` writes no
specialisation name into anything.

**One thing that contradicts the common account.** `Potion Master` (28675) gates exactly one
item on Mists, where it *is* taught under Alchemy - so "alchemy specialisations have no
exclusive recipes" is true on Era and Burning Crusade and false by one item on Mists. It is in
the table because the client says it belongs there.

**What this cannot cover.** A specialisation recipe taught only by a trainer has no item and
therefore no row. That is the right shape for a tooltip - there is nothing to hover - and it is
a real gap for any other question, so nothing here should be read as a complete list of what a
branch can make.

#### Naming every branch, including the ones that gate nothing, measured 2026-09-06

The route above finds a branch only where some *item* requires it, which was exactly right
while the only question was "can this character learn this recipe". It is not enough to answer
"which branch did they take": **two of Burning Crusade's three alchemy masteries gate no item
at all** - Transmutation Master 28672 and Elixir Master 28677 teach through a trainer - so they
were missing from the table for as long as it existed.

A second route now runs beside it and the two are merged. A branch is a `SkillLineAbility` row
under a primary profession that is **all** of:

| clause | what it excludes |
|---|---|
| `MinSkillLineRank` 1, `AcquireMethod` 0, `TrivialSkillLineRankHigh` 0, `TradeSkillCategoryID` 0, `NumSkillUps` 1 | every recipe |
| outside the `SupercedesSpell` chain, in either direction | Apprentice through Artisan - **9785 Artisan Blacksmithing looks exactly like a branch without this** |
| carries `SpellEffect.Effect` 47, *grants a trade skill* | Prospecting 31252, Herb Gathering 2366/2369/2371, and two others: abilities a profession **grants** rather than branches it **offers** |

Each clause was measured rather than reasoned about. With the supercedes test and without
effect 47, Era answers 15 where it should answer 10; with effect 47 and without the supercedes
test it answers 35. With both:

| build | branches |
|---|---|
| Classic Era | 10 |
| Burning Crusade | 16 |
| Mists | 5 |

**Mists' five are engineering's two and alchemy's three**, which is the right answer for a
build where the smithing, leatherworking and tailoring branches were taken out of the game -
and it is the one thing here nobody had to be told, because the sieve found it.

The union is **16 branches across 5 professions**, and no name for any of them is shipped.

**Which branches a character took is read out of the spellbook, not asked for.** The book is
already walked by `Scanners/Character.lua` and stored as ids; the branches are the entries the
shipped table recognises. `IsSpellKnown` would answer it in one call each and is a client call
nothing in Family has ever made on three builds, which is a worse trade than sieving a list
already in hand. §2.2 falls out of the book itself: **no book, no answer** - a spellbook that
cannot be read leaves the old record alone, and one that can be read and holds no branch clears
it, because a character who never chose is not a character nobody looked at.

They are written to **meta and not the payload** the book lives in. The summary reads meta and
nothing else, which is what lets it cost the same for forty members as for four, and a list of
branches is three numbers where a spellbook is a thousand.

#### A spellbook row is not always one of this character's spells

Read 2026-09-09 on Mists of Pandaria, on a hunter of level three or four whose Abilities & Talents
page listed Stampede, Trueshot Aura, Trap Launcher and Scatter Shot, with a row reading *Spell #9*
and no icon among them. Asking every position of the book for its **first** return - the one
`Character:ReadSpells` had discarded since the beginning:

    20 FUTURESPELL 33388     36 FUTURESPELL 5116      44 FUTURESPELL 781
    23 FUTURESPELL 90267     37 FUTURESPELL 1462      76 FUTURESPELL 121818
    27 FUTURESPELL 130487    38 FUTURESPELL 2641      31, 81, 141, 199  FLYOUT 9

Fifty-two rows in all, and every one of them wrong to record:

- **`FUTURESPELL`** is the greyed row the game draws to say *you will learn this at level 60*.
  5116 is Concussive Shot and 781 is Disengage - abilities that character does not have.
- **`FLYOUT`** is a group of spells rather than a spell, and the second return is then a
  *flyout* id rather than a spell id. Nothing can name flyout 9, which is the *Spell #9*.

**Only Mists has answered this call anywhere in this repository**, which decides how the rule is
written. Family drops the two kinds that have been read and keeps everything else, narrating any
kind that is neither those nor `SPELL` - because keeping only `SPELL` would empty every spellbook
on a client that happened to answer with some other word, and §2.2 refuses exactly that trade.

The blast radius is wider than the page that showed it: `Character:ReadSpecialisations` reads the
same book, and a linked family is sent it - so a character could share a claim to abilities they
have not got. A stored book carries no kinds and cannot be re-filtered, so each character corrects
itself the next time it is played.

**And it is only half the answer, read the same day.** `FUTURESPELL` is how the *class* tab marks
what a character has not learned yet. A **specialisation** tab does not mark them at all. Asked
tab by tab on the same hunter, keeping only the rows answering `SPELL`:

    Marksmanship  57 rows   Stampede, Camouflage, Kill Shot, Chimera Shot,
                            Mastery: Wild Quiver, Trueshot Aura, Aimed Shot ...
    Survival      56 rows   Explosive Shot, Black Arrow, Lock and Load,
                            Mastery: Essence of the Viper ...
    Beast Mastery 13 rows   read, and the top of that tab was lost off the chat frame

Every one of those answered `SPELL` on a character of level three or four. So on Mists a
specialisation tab is a **price list of what the specialisation can do**, exactly as the trainer's
Craft window is a price list rather than an offer - not a record of what this character holds. The
class tab is the one that answers the question Family is asking.

The same reading says how heavily they overlap: of the 72 distinct ids visible in the untruncated
part, **46 appear under more than one tab and 8 under all three** - Arcane Shot, Auto Shot, Snake
Trap and Stampede among them. That is why the page drew one ability several times; the repetition
is the spec tabs, not a fault of its own.

**What separates them, measured the same day.** `GetSpellTabInfo` answers with more than the four
returns Family had been taking:

    1 General        132219  0    28  false  0    false  nil
    2 Hunter         626000  28   48  false  0    false  nil
    3 Beast Mastery  461112  78   60  false  253  false  253
    4 Marksmanship   236179  138  58  false  254  false  254
    5 Survival       461113  196  57  false  255  false  255

The **sixth** return is nought for the two tabs that are this character's and a specialisation's id
for the three that are not; the eighth says it a second way. Family reads the sixth, and treats
*absent* as *not a specialisation* - Era and Burning Crusade have never answered this call here, and
a client that returns four values must not lose its whole spellbook to a nil. The harness holds
that: a mutation making a silent tab count as a specialisation reddens the ordinary spellbook
checks, not only the new ones.

**A `FLYOUT` row stands for spells rather than being one.** On Mists **Call Pet** is one button
that opens into Call Pet 1 to 5, so dropping the row - which is right, since a flyout's id is not
a spell id and storing it is what drew *Spell #9* - also drops everything the character keeps
behind it. Family now opens it: `GetFlyoutInfo` for how many slots, `GetFlyoutSlotInfo` for each.

**Confirmed on a live client 2026-09-09**, by `/family spellbook` on a level-five Mists hunter -
the two calls were written against before either had been read, and the reading agrees with what
was written:

    Hunter: 48 row(s), read.
        Arcane Shot   3044          flyout 9 Call Pet, 5 slot(s)
        Auto Shot     75                Call Pet 1   883     true
        Revive Pet    982               Call Pet 2   83242   false
        Steady Shot   56641             Call Pet 3   83243   false
        Focused Aim   87324             Call Pet 4   83244   false
        Tracking      118424            Call Pet 5   83245   false
        and 41 row(s) passed over: FUTURESPELL 41

So `GetFlyoutInfo` answers a **name** and a **slot count**, and `GetFlyoutSlotInfo` answers a spell
id and, third, a **boolean** for whether this character has it. Call Pet 1 is kept and Call Pet 2
to 5 are not, which is what a hunter of that level holds. The same reading settles the hunter's
other pet spells: Mend Pet, Tame Beast, Dismiss Pet, Feed Pet and Beast Lore are among the 41 that
answered `FUTURESPELL`, so the client is saying the character has not learned them - Family is not
losing them.

The **General** tab on the same character reads 19 of its 28 rows, the other 9 being the riding
skills and the rest of what the character will get later.

Nothing they say is believed on its own even so. A slot is kept only where it says it is *known* **and** the id it gives is one this client
will name - two answers agreeing, the same standard `AgreesWithRow` holds a craft row to. Under any
other shape, including the calls being absent altogether, nothing is kept and the row is dropped
exactly as it was, which is the worst case rather than a new one. The first login on a client that
has them narrates the flyout, its name and how many slots were kept, so the reading arrives without
anybody going to look for it.

**Read on a character too low to have chosen**, so all three specialisation tabs are somebody
else's. What a character with an *active* specialisation answers here has not been read, and is the
second reason the walk also records **one ability once**, under the first tab that holds it: if an
active specialisation's tab answers nought, its spells are that character's *and* the class tab's,
and the tab rule alone would leave the repetition standing above level ten while removing it below.

#### Which branch is which, measured 2026-09-06

Alberto supplied the sixteen icon file ids from his own three clients, by name. Attaching them
to spell ids needed the names, and **the names cannot be inferred from anything already cached**:
`SkillLine` and `SkillLineAbility` carry no spell name, and the items a branch gates say the
opposite of the truth - 17041 gates *The Planar Edge*, *Black Planar Edge* and *Wicked Edge of
the Planes*, which read as an axesmith's work and are the swordsmith's.

So `SpellName` was fetched from wago at build 2.5.6.69110, which carries all sixteen:

| | | | |
|---|---|---|---|
| 9787 Weaponsmith | 9788 Armorsmith | 17039 Master Swordsmith | **17040 Master Hammersmith** |
| **17041 Master Axesmith** | 10656 Dragonscale | 10658 Elemental | 10660 Tribal |
| 20219 Gnomish Engineer | 20222 Goblin Engineer | 26797 Spellfire | 26798 Mooncloth |
| 26801 Shadoweave | 28672 Transmutation Master | 28675 Potion Master | 28677 Elixir Master |

**17040 and 17041 are the wrong way round from the obvious guess**, which is the whole reason
this was measured rather than typed: an earlier session had written *Master Axesmith* against
17040 in a test fixture, from memory, and it was wrong.

Every one of Alberto's sixteen labels matched exactly one of these; the only differences are
cosmetic (*Potion Mastery* for `Potion Master`, *Goblin engineering* for `Goblin Engineer`), and
none of them is ambiguous between two branches. The ids live in `tools/specialisations.py`, hand
data in a generated file, which is the arrangement `tools/skill-lines.py` already has and is
here for the same reason: a texture cannot be probed, so the only honest source is somebody
looking at one.

`SpellName` is not a build dependency of the tool. It was fetched to establish the mapping once
and the mapping is now written down; re-running the generator does not read it.

**What is not covered.** Mists' six cooking ways are **child skill lines** - 975 to 980, parent
185, category 9 - and not spells taught under a profession, so the sieve above does not see them
and neither would the spellbook. The spells that grant them (124694, 125584, 125586-125589,
by `SpellEffect` 118) are the trainer's, and whether any of them stays in a character's book is
unmeasured. See backlog 24.

### What the skill sheet actually holds, measured 2026-09-06

From two screenshots of the character sheet's *Skills* tab, an Era rogue and a Burning Crusade
rogue, and they are the same shape. One list, three headings, and **the scanner reads all three**:

| heading | on it |
|---|---|
| Class Skills | Assassination, Combat, **Lockpicking**, **Poisons**, Subtlety |
| Professions | Leatherworking, Skinning, Engineering, Mining … |
| Secondary Skills | Cooking, First Aid |

**So lockpicking and poisons come off the sheet like anything else.** The scanner said otherwise
in a comment for weeks - *a profession the skill list does not carry: rogue poisons* - and it was
wrong; the branch it justifies has never fired for them.

**And they cannot be unlearned**, which is Alberto's own note and is the part that matters for
pruning: a skill that cannot leave the sheet can never be read as having left it, so the prune in
`Scanners/Professions.lua` can never reach them however the marking works out.

**Every class's talent branches are on that list too, and are not professions.** Visible in the
same screenshot: *Assassination*, *Combat* and *Subtlety* under Class Skills with **no rank and
no maximum** - and Alberto's note is that it is every class, a mage's Frost, Fire and Arcane
sitting there the same way. `readSkillList` requires `maxRank > 1` before calling anything a
profession, so they reach `everything` - the widest set, used only to tell "the sheet was read"
from "the sheet could not be read" - and never reach `skills`. Without that one test a rogue's
professions column would lead with *Assassination*.

**Burning Crusade is the same as Era here.**

### Mists has no skill sheet at all, measured 2026-09-06

Two screenshots from Alberto's own death knight, and the shape is not the one above.

**There is no Skills tab.** There is *Spellbook & Abilities*, with a **Professions** page: the
learnt ones with a rank and a bar - *Inscription, Apprentice 1/75*, *First Aid, Artisan 270/300* -
a *Second Profession* slot, and the unlearnt ones described rather than ranked (*visit a trainer
to learn archaeology*). That is what `GetProfessions` answers, and `ReadRanks` merges the modern
call's answers into `everything` as well as into `skills`, so the two guards that lean on
`everything` work there exactly as they do on a sheet.

**Runeforging is not on that page.** It is in the **spellbook**, as a passive spell, present in
every branch - so a death knight acquires it whatever specialisation they take. Alberto sent the
tooltip: *allows the Death Knight to emblazon their weapon with runes*.

**Which confirms the case the scanner's window branch exists for**, and it was the last one still
resting on a comment. Runeforging is a window full of things to make and a skill on no list any
client keeps, so it reaches Family only through its own window and never through `GetProfessions`.
It is therefore never marked `onSheet` and the pruning in `Scanners/Professions.lua` can never
reach it - not by an exception naming it, but because nothing ever told Family a sheet had it.

### Which professions make nothing, measured 2026-09-06

The professions panel used to file herbalism, skinning, fishing and a rogue's lockpicking under
*never opened*, which is a claim about a client rather than about a record: there is no window
to open. Alberto asked for lockpicking to be said properly and then pointed out that herbalism
and skinning are the same case.

**Counting rows under a skill line does not separate them.** On Era, `SkillLineAbility` gives
Herbalism 8, Skinning 4, Fishing 5 and Mining 22 - a threshold nobody could defend.

**Counting rows whose spell creates an item does**, `SpellEffect.Effect` 24:

| build | Blacksmithing | Cooking | Mining | Herbalism | Skinning | Fishing | Lockpicking |
|---|---|---|---|---|---|---|---|
| Classic Era | 315 | 89 | 13 | 0 | 0 | 0 | 0 |
| Burning Crusade | 385 | 116 | 21 | 0 | 0 | 0 | 0 |
| Mists | 829 | 240 | 32 | 0 | 0 | 0 | — |

**With one clause that is not optional: the spell must belong to exactly one skill line.** A
recipe belongs to one profession; a spell filed under two is something else wearing a recipe's
clothes. Without it Mists gives Herbalism and Skinning one maker each - the same spell, 110955,
sitting under both - and the rule turns back into a threshold.

**Mining is not a gathering profession by this test and that is correct.** Its window is
Smelting's, and Smelting's recipes are filed under Mining, so the table answers *makes things*
without anybody having to name it. A rule written from the sound of the words - "gathering
professions" - would have swept it up.

The flag is emitted as `makes = false` and only where it is false, so **a skill line newer than
the shipped table is treated as an ordinary profession** and lands in the buckets that describe
what Family did or did not read, rather than being explained away as having nothing to show.
Thirty-one lines carry it: every weapon, every riding line, and those four.

### The same name calls on Era, measured 2026-08-30

`/family guild names` on Classic Era, realm Pyrewood Village, in a 773-member guild:

    UnitName("player")        -> 1:Nervina(string) 2:nil(nil)
    UnitFullName("player")    -> 1:Nervina(string) 2:PyrewoodVillage(string)
    GetRealmName()            -> 1:Pyrewood Village(string)
    GetNormalizedRealmName()  -> 1:PyrewoodVillage(string)
    GetAutoCompleteRealms()   -> 1:{PyrewoodVillage, NethergardeKeep, MirageRaceway}(table)
    GetNumGuildMembers()      -> 1:773(number) 2:13(number)
    GetGuildRosterInfo(1)     -> 1:Carlingblack-NethergardeKeep(string) ...
                                 17:Player-5284-01C325A6(string)

**Every one of these calls exists on Era**, and answers in the same shapes as Mists: the realm
absent from `UnitName`, present and normalised on `UnitFullName`, spaced on `GetRealmName`. So
the `SameRealmGroup` widening of `Offering()` works on this client rather than falling back.

**Era has connected realms too** - three of them - and **all 773 roster entries carry a realm**,
including `Carlingblack-NethergardeKeep` from another realm of the group. Cross-realm guild
membership on Era is therefore measured, not inferred.

**No name collision in 773 members.** A far stronger negative than the five-member guild the
same question was asked of on Mists, and still not a proof that a connected group forbids
duplicates - only that this guild has none.

**`GetNumGuildMembers` answers in two values here as well** (773 and 13), so the `tonumber(5, 2)`
fault would have bitten identically on Era. See L-031.

### The same name calls on Burning Crusade, measured 2026-08-30

    UnitName("player")        -> 1:Milionario(string) 2:nil(nil)
    UnitFullName("player")    -> 1:Milionario(string) 2:Thunderstrike(string)
    GetRealmName()            -> 1:Thunderstrike(string)
    GetNormalizedRealmName()  -> 1:Thunderstrike(string)
    GetAutoCompleteRealms()   -> 1:{}(table)
    GetNumGuildMembers()      -> 1:2(number) 2:1(number)
    GetGuildRosterInfo(1)     -> 1:Milionario-Thunderstrike(string) ...

**Every call exists on all three clients.** `UnitName` never gives the realm, `UnitFullName`
and `GetNormalizedRealmName` always do, and the roster always qualifies a name - two entries
here, both carrying a realm, on a realm with no partners at all.

**`GetAutoCompleteRealms` answers an empty table, not nothing.** The call is present and the
list is empty, which is what a realm outside a connected group returns. That is a different case
from the call being absent and `SameRealmGroup` has to narrow to an exact match for both - an
empty list must not be read as "everything is connected". The absent-call case was the one
written from imagination; this is the one most realms will actually hit.

**`GetRealmName` and `GetNormalizedRealmName` agree here**, both `Thunderstrike`, because the
name has no space. The two differ only where one does, which is why the comparison strips
spaces from both sides rather than trusting either call.

### `tools/charged-items.py` — which items can carry more than one charge

`addons/Family/ChargedItems.lua` is generated from `ItemEffect.Charges` and holds **355 item
ids** — the union of the three pinned builds, each mapped to the largest maximum seen for it.

| build | items with 2+ charges | new to the union |
|---|---|---|
| Classic Era `1.15.9.69109` | 181 | 181 |
| Burning Crusade `2.5.6.69110` | 158 | 68 |
| Mists `5.5.4.69078` | 246 | 106 |
| **union** | | **355** |

It exists to be a gate rather than an answer. The charge count a player wants is the one on the
item in their bag, which is only in the tooltip; a tooltip per slot is not free when a bag is
eighty slots of mostly cloth, so a slot whose item is not in this table is never tooltipped.

**Items with exactly one charge are deliberately absent** — four to ten thousand per build,
every potion and scroll in the game, and they show no charges line at all.

**The union rather than a table per build.** An id means the same item wherever it exists, the
set is small, and choosing between per-build tables would need a client check this project does
not make.

**No charged item stacks.** Of the 187 ids in the table that Era's `ItemSparse` knows, not one
has `Stackable` above 1. So a charge count and a stack count are never both interesting for one
slot, and a panel drawing charges where the stack count would go displaces nothing.

**What is actually in it**, because 355 sounds larger than it is: 73 of Era's 181 are one family
of quest items (`Deputization Authorization: Ashenvale Mission I` through `IX`), and the useful
core is nearer a hundred — the oils at 5, Bag of Marbles and Bethor's Potion at 10, Triage
Bandage and Rune of Recall at 20, Elune's Candle at 88, Bottomless Noggenfogger Elixir at 200.
The chaff is kept: filtering it would mean a judgement about what matters, encoded in a
generator, that goes stale the day Blizzard adds something. A charge count is a charge count.

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
| `ItemEffect` | `ParentItemID` → `SpellID`, which links a recipe item to what it teaches; and `Charges`, the maximum an item carries |
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

#### The two prices, and what only one of them means

Measured 2026-09-10 on the pinned Era build, after Alberto was asked whether Family could show
vendor prices the way a dedicated addon does. `ItemSparse` carries both, at columns 59 and 60:

    24442 rows        SellPrice non-zero 18419        BuyPrice non-zero 19004

**`SellPrice` is what a vendor pays you**, and the client hands the same number to any addon
through `GetItemInfo` without anything being fetched or shipped. Nothing here is needed for it.

**`BuyPrice` is exact, and it is not a statement that anything sells the item.** Checked against a
thing many vendors really do stock, `Weak Flux` (2880): sell 25, buy 100 - and 1 silver is what a
vendor charges for it, so the number is right. Then checked against things no vendor anywhere
sells:

    17182  Sulfuras, Hand of Ragnaros   forged      buy  1663117   (166g)
    16820  Nightslayer Chestpiece       raid drop   buy   215686   (21g)
    15138  Onyxia Scale Cloak           crafted     buy    75993   (7g)
    15410  Scale of Onyxia              raid drop   buy    20000   (2g)

4093 epics and 29 legendaries on Era carry one. **And absence does not mark the other case
either**: exactly **4** items in the whole Era table have a `SellPrice` and no `BuyPrice`, against
589 with a buy price and no sell price. The column is set on nearly everything.

So the line does not fall between the two prices. It falls between **what a thing costs**, which is
in the client's own table and exact, and **whether anything sells it**, which is not in any client
table at all - vendor inventories live on the server. That is the work a site like Wowhead does by
hand, gathered from players walking past the NPCs, which is why it can hold three different figures
for one flux: they are photographs taken by different characters at different reputations.
`wago.tools` mirrors the client's files and does no such gathering.

The specification refuses the second half by name (§2.5, *where an item is looted, **sold**,
quest-rewarded or otherwise obtained*).

**And it cannot be fetched once and shipped, because there is no table to fetch.** Asked directly,
2026-09-10: wago.tools lists every DB2 it serves, and nothing in that list maps a vendor to what it
sells. The three that come closest are not it and are not served for these builds anyway -
`CollectableSourceVendor`, `CollectableSourceVendorSparse` and `PerksVendorItem` are retail tables
about collectables and the Trading Post, and all three answer `{"errors":"Table not found."}` for
`1.15.9.69109`. `Creature` is display and type data and holds no inventory. Vendor stock lives in
the server's own database, which is not published in any form, which is why a catalogue site has to
gather it from players walking past the NPCs.

So *at least one vendor sells this* cannot be delivered up front from the client's data. It can
only come from a compilation somebody else made - which is reserved (`CLAUDE.md`, adopting a new
data source) and is the case §2.5 describes - or from the merchant frames the player opens, which
is what a catalogue site is itself made of.

#### Disenchanting: the client knows the band, not what comes out of it

Asked 2026-09-10 - could a tooltip name the shards an item might disenchant into, with their
odds? `ItemDisenchantLoot` **is** served, on all three builds, which is further than the vendor
question got:

    Era 50 rows    Burning Crusade 74    Mists 116
    ID, Subclass, Quality, MinLevel, MaxLevel, SkillRequired, ExpansionID, Class

    group 3   class 2  quality 2  ilvl 5-15    group 23  class 4  quality 3  ilvl 41-45
    group 4   class 4  quality 2  ilvl 5-15    group 25  class 4  quality 2  ilvl 41-45

Each row is a **band**: a class (2 is weapons, 4 is armour), a quality, and an item-level range,
answering with a group id. So the client can say which group a thing falls into, and that is the
whole of what it says. **There is no companion table with the outcomes** - the served list holds
`ItemDisenchantLoot` and nothing else of the kind, `ItemSalvage` and `ItemSalvageLoot` being a
different and retail-only thing. Which shards a group yields, and with what probability, is a
server loot template and is published nowhere.

`SkillRequired` is **nought on all fifty Era rows**, so it does not carry the requirement either.

**What can be said honestly, and it is not nothing.** Whether an item is disenchantable at all,
and which band it is in - both from the client. And, in the shape Family is actually for, **who in
the family could do it**: enchanting and its rank are already recorded for every member, so *who
can disenchant this* is the same question as *who can make this*, asked backwards. Naming the
shards is the part that would need a catalogue somebody else compiled, which is reserved
(`CLAUDE.md`) and is the case §2.5 describes.

#### Loot: the bosses are in the client, on one of the three

Asked 2026-09-10, straight after the vendor question and with the same shape. Measured:

    JournalEncounterItem   1.15.9.69109   404 Table not found
    JournalEncounterItem   2.5.6.69110    404 Table not found
    JournalEncounterItem   5.5.4.69078    8563 rows, 7259 distinct items
    JournalEncounter       5.5.4.69078    454 encounters
    JournalInstance        5.5.4.69078    85 instances

    ID, JournalEncounterID, ItemID, FactionMask, Flags, DifficultyMask, DisplaySeasonID

That is the Adventure Guide's own loot listing - **dungeon and raid bosses only**, and only on the
client that has an Adventure Guide. It is not general loot: a wolf's meat, world drops, rare
spawns, gathering, quest rewards and vendor stock are all server data and appear in no client
table on any build.

**Worth writing down because it is a real tension in §2.5, not a closed question.** That section
refuses *where an item is looted* by name, and the reason it gives is that such things *need facts
the client does not hold*. For Mists boss loot the client does hold them, which is the same
exemption §2.5 grants the generators in `tools/`. So the letter refuses and the reason does not.
Changing that is a specification decision and is Alberto's.

Recommended against, for reasons that are not about the data: one client of three; the Mists client
already draws it in its own Adventure Guide; and it says nothing about members, which is what
Family is for.

**Noticed while looking:** `ItemPriceBase` *is* served for Era - 1301 rows of `ItemLevel`, `Armor`,
`Weapon` - which is where an equippable item's prices are generated from, and why the buy/sell
ratio clusters at ×5 for gear and ×4 for trade goods rather than being one number.

**Which closes the question about shipping the table.** Draw `BuyPrice` only for items seen on a
vendor and the table buys nothing - the price was on the vendor's own list, already discounted.
Draw it for the rest and Family states 166 gold for Sulfuras. The 253 KB purchases exactly the case
in which it cannot tell the truth.

**And it cannot be derived from the other.** The obvious guess is that buy is a fixed multiple of
sell; it is not. Of the 18415 items carrying both, 50.2% are ×5, 24.1% are ×4, and the rest run
from ×1 to ×7 with no pattern - *Bent Staff* is ×5.222 and *Worn Axe* ×5.429. A shipped table is
the only way to have them, at 19004 entries and about 253 KB for Era alone, before the other two
clients.

**What is true by construction is the merchant's own list.** With a vendor open,
`GetMerchantItemInfo` states the price of a thing that is, demonstrably, for sale - with the
reputation discount already applied, which no table can carry.

**Which is what Family reads, in `Scanners/Merchant.lua`.** Four calls, all through `TryCall` and
all validated before anything is kept, because none of them has been read on a client here:
`GetMerchantNumItems`, `GetMerchantItemInfo` (name, texture, price, quantity),
`GetMerchantItemLink` for the id, and `GetMerchantItemCostInfo` for whether the row costs something
other than money. A row is recorded only where the id resolves, the cost has no extra components,
the price is positive and the quantity divides it exactly. Under any other shape nothing is
recorded, which is the safe direction.

**The highest sighting is the one kept.** Not a judgement about which reading is better, but the
one direction a discount can move: a vendor asks the same base of everybody and reputation only
lowers it, so the largest figure any character was quoted is the closest observation comes to the
base, and every further sighting can only improve it. Keeping the newest would let one exalted
character understate the price for the whole family; keeping the lowest would do it for good.

A pleasant consequence: what this converges on **is** `ItemSparse.BuyPrice`, the column deliberately
not shipped - but only for the items somebody can actually buy, which is the half the column cannot
tell apart.

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

### What a large family costs to share, measured 2026-09-08

Asked because a player with two accounts reported the game pausing at every login with Wide
Family on, and then because Alberto asked what the worst plausible case looks like: fifteen
links of two hundred and ten characters each, half of them with a hundred bag slots, a hundred
bank slots, a hundred and fifty letters and a profession of three hundred and fifty recipes.

Sized with the addon's own LibSerialize and LibDeflate, against `Comm.lua`'s own rate - ten
messages a second, `PER_TICK` 2 every `TICK` 0.2. At the 200-character piece those measurements
were taken with, that is **2,000 bytes a second, per client**; it is about 2,300 now, for the
reason in the next section. The members are made
different from each other on purpose: made identical, deflate folds two hundred of them into
almost nothing and the answer is a fiction. Times are lua5.1 on the machine this was written on;
**a game client measured about three times slower** on the one comparison there is - a mark that
costs 0.14 ms here was 0.8 ms there.

| | on the wire | to pack, in one frame |
|---|---:|---:|
| one member of the heavy sort | 3.6 KB | |
| a friend's 210, one bundle, level 5 | 750 KB — **6 min** | 2,461 ms (~7.4 s on a client) |
| the same, 18 batches of 12 at level 1 | 1,074 KB — **9 min** | 122 ms (~0.4 s on a client) |
| your 210 sent to each of fifteen links | 11 MB | **1.6 hours out of one client** |

The last row is the ceiling and no amount of packing touches it: the same records go out once
per link, and one client has one queue at 2 KB a second.

**Deflate's level, on the same bundle of seventy ordinary members:**

| level | to pack | bytes |
|---:|---:|---:|
| 1 | 225 ms | 211 KB |
| 3 | 282 ms | 208 KB |
| 5 | 577 ms | 195 KB |
| 9 | 4,834 ms | 174 KB |

**Batch size, on the same seventy:** batches of 12 cost 178 ms a frame and 27% more bytes than
one bundle; of 8, 133 ms and 42%; of 5, 87 ms and 63%. Compression sees less at a time, so the
smaller the batch the more it costs to carry.

**Guild share is a different shape and is not near any of this.** Its announcement carries a
profession's *count and fingerprint* rather than its recipes, so one answer about six alts is
1.4 KB and a recipe list, asked for when somebody opens one, is 0.9 KB. In a guild of six
hundred with a hundred and fifty online, answering every announcement costs 7 KB a minute
against a budget of 117 - six per cent. It only becomes tight at the pathological end: a hundred
and fifty players each switching character every two minutes is 75 announcements a minute, and
if every one of them were new to us that is 107 KB a minute, or 91% of the budget. What makes it
*not* tight in practice is the traffic control skipping an exchange with anybody whose data we
already hold - though that skip is keyed on the sender's **character** name, so each of a
player's six alts is a stranger the first time it announces.

### How much of an addon message is Family's own header, measured 2026-09-08

The game carries 255 characters in an addon message. `Comm.lua` puts its own header on the
front of every piece - the message id, which piece this is, how many there are, the kind, and a
separator after each - and the rest is payload. Measured against the format string it really
uses:

| kind | id | pieces | header | room |
|---|---:|---:|---:|---:|
| `data` | 1 | 1 | 11 | 244 |
| `data` | 99 | 5,000 | 17 | 238 |
| `data` | 99,999 | 9,999 | 21 | 234 |
| `ghello` | 99,999 | 9,999 | 23 | 232 |

Family used to cut every piece at a flat **200**, which is between 14% and 18% of each message
left empty - on the slowest thing in the addon, where a large family is an hour and a half of
queue. Each piece is now sized by the header it will actually carry, keeping three characters
back from the game's number: what a client does with a message of exactly 255 is the one thing
here nobody has watched, and being wrong about it truncates silently and costs a whole transfer
rather than a message.

| body | messages before | messages now | at ten a second |
|---:|---:|---:|---:|
| 4 KB | 20 | 17 | — |
| 200 KB | 1,024 | 868 | 1.7 min → 1.4 min |
| 11 MB | 57,672 | 49,717 | 96 min → 83 min |

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

### Honor: what it is on each build, researched 2026-09-04

Asked for from play: track honor, rank, this week's progress and how much is missing for the
weekly cap. Written down before any code because **honor is not one thing across the three
builds** — it is three systems that share a word, and the shape that has already produced three
per-expansion tables in this project.

**This section is documentation, not measurement.** Every line below comes from patch notes and
the wiki, cited. Nothing here has been asked of a client, and none of it says which call
answers what — that is the probe list at the end, and it is what has to exist before anything
is stored.

#### Classic Era `1.15.9` — ranks, and the old description is wrong

The vanilla system every guide describes — Contribution Points, a weekly recalculation against
everybody else on your realm and faction, ranks decaying if you stop — **was replaced in patch
1.14.4**. The patch notes say so directly:

> Ranking Points have been eliminated, Honor is visible immediately after each Honor Kill (or
> Dishonorable Kill), and de-ranking is no longer a factor

and

> your Rank is no longer determined by a comparison with other players, and the amount your
> rank increases each week during the weekly reset is solely determined by your PvP efforts in
> a given week

with a number that matters here more than anywhere:

> Maximum honor gains for the week are currently set to 500,000 Honor per week.

So on Era all three halves of the request are real and they are the same half: fourteen ranks
from Private to Grand Marshal or High Warlord, honor earned this week, and a **weekly cap of
500,000** that a character can be short of. Rank advances at the weekly reset, by that week's
honor alone.

Source: [Patch 1.14.4](https://warcraft.wiki.gg/wiki/Patch_1.14.4),
[Honor system (Classic)](https://warcraft.wiki.gg/wiki/Honor_system_(Classic)).

#### Burning Crusade Anniversary `2.5.6` — a currency, and no rank at all

Patch 2.0.1 removed the rank system. Honor became a currency that accumulates, is spent on
rewards, and **does not decay**. The cap is described only as *approximately twice the most
expensive reward*, which is not a number anything can be built on — it has to be read from the
client if it is to be shown.

Weekly progress on this build is **arena points**, not honor. They are awarded once a week from
the player's highest-earning team format, on a curve from team rating: 2v2 earns 76% and 3v3
88% of the 5v5 rate. A team needs at least ten matches that week and the player at least 30% of
them. The stockpile cap cited is 10,000, and that figure reaches the wiki through a Wrath
Classic hotfix rather than through TBC itself — so it is exactly the kind of number to measure
rather than ship.

So *how much is missing for the weekly cap* has no meaning here as asked. What has meaning is
the arena award and whether the character qualified for it.

Source: [Honor system](https://warcraft.wiki.gg/wiki/Honor_system),
[Arena Points](https://warcraft.wiki.gg/wiki/Arena_Points).

#### Mists of Pandaria `5.5.4` — two currencies, and a cap that is per player

Two currencies at once. **Honor** comes from unrated play and has a hard total cap of **4,000**,
enforced since patch 4.0.3a. **Conquest** comes from rated play, and from patch 5.4.0 its weekly
cap is **based on the player's own rating** — it is shown in the Rated pane of the PvP interface
rather than being a constant. Earn rates: 180 for an arena win, 400 for a rated battleground
win, up to 200 for a rated loss, 150 for the first random battleground won each day, 75 for
later wins, 50 for a daily PvP quest. Nothing above the weekly cap is earned, and neither
currency carries between seasons.

So *the weekly cap* here is the conquest cap, it differs per character, and **Family cannot
compute it** — it can only read it or say nothing.

Source: [Conquest Points](https://warcraft.wiki.gg/wiki/Conquest_Points),
[Honor Points](https://warcraft.wiki.gg/wiki/Honor_Points).

#### What that means before a line is written

| | Era | Burning Crusade | Mists |
|---|---|---|---|
| rank | 14, earned weekly | gone | gone |
| honor | points, weekly cap 500,000 | currency, cap unstated | currency, total cap 4,000 |
| the weekly thing | honor toward the cap | arena points, from team rating | conquest, cap per player |
| decay | removed in 1.14.4 | none | none |

One word, three systems. A single "honor" column would be wrong on two builds out of three, and
a shared cap constant would be wrong on all three for different reasons.

#### The probes this needs, none of them run yet

Nothing above says which call answers what, and the client is the only authority on that. Per
build, and read back rather than assumed:

- **Era.** Which call gives the rank and its name, whether the name arrives localised, what
  reports honor earned *this week* as distinct from lifetime and from this session, and whether
  the 500,000 cap is readable anywhere or would have to be shipped as a constant — a constant
  the patch notes themselves call *currently*.
- **Burning Crusade.** Which call reports the honor currency and its cap; whether arena points
  and a team's rating are readable from the character rather than from the arena frame; and
  what a character with no team answers.
- **Mists.** Which call reports honor and conquest; and above all **whether the conquest weekly
  cap is readable**, since 5.4.0 shows it in the Rated pane and something must expose it. If it
  is not readable, the answer is that Family says nothing about the cap on that build, which is
  §2.2 and is better than a number that is right for one character in ten.

Until those are answered, the honest position is that Family stores no honor at all.

#### Re-read this at a new build

The rules above are pinned to the three builds in section 3 and to no others. They have already
changed once inside a single expansion — 1.14.4 replaced the ranking system that every guide
still describes — so *the rules of the game* are a per-build fact exactly as `SpellCooldowns` is,
and the difference is that nothing here re-runs to tell us.

**When a pinned build moves, this section is re-read by hand.** That is the price of the source
being a page rather than a table, and it is written here rather than trusted to memory. The
generators refuse and shout at a new build; this one cannot, so it says so.

### Where facts may come from, and how each may be used

Three kinds of source, and the difference is not how reliable they are — all three are reliable —
but what may be taken from each and by what means.

**The client.** The authority on everything it will answer. Asked by id, with capability probes
whose answers are read back. Nothing on this page outranks it.

**`wago.tools`.** The client's own tables, served per build as CSV, fetched mechanically by
everything in `tools/`. Section 3 pins the builds. This is the sanctioned machine-readable
source and the only one.

**Published pages — Wowhead, the wikis, patch notes.** Read for *rules and shapes*, never
harvested for data. The distinction is the one their terms draw and it is worth stating in our
own words:

- A **fact** is free to know and to restate: *Era caps the week at 500,000 honor* is a rule of
  the game, and it belongs in a sentence of ours with the source beside it.
- A **table** is the product of somebody's work. Ids, item lists, spell data — those come from
  the client or from wago, never from a page, however much quicker the page would be.
- **Bulk mechanical extraction from those sites is out**, and that is a rule about method rather
  than about volume: a scraper pointed at Wowhead is the thing their terms name.

The practice predates this paragraph. The Chronoboon buff names above came from a Wowhead render
and were used **only as search terms** — every id and every icon was then resolved from the
client's own tables, which is the shape every future use should take.

Two practical notes. Wowhead does not render for an automated fetcher at all — its article
bodies come back as navigation — so reading it means a person reading it and pasting what
matters, which is also the tidier answer to the question above. And `warcraft.wiki.gg` publishes
its text under **CC BY-SA 4.0**: citing a fact and linking the page costs nothing, while pasting
its prose into these documents would carry the share-alike with it. Quoting Blizzard's own patch
notes briefly, with attribution, is what the honor section does.

### Lockpicking, and a skill that is not on every build

`tools/skill-lines.py` takes skill line **633** by id, the way it takes the four secondaries,
because it is in category 7 with the class skills rather than in 11 with the professions.

**It is on Classic Era and Burning Crusade and not on Mists**, measured rather than remembered:
the 5.5.4 SkillLine table has 175 rows and none of them is 633, which matches the skill having
been taken out of the game after Cataclysm. The generator needs no rule for that — a build whose
table does not carry a line contributes no name — but it is why that entry has names from two
builds and not three, and why a check demanding every locale of every build for every entry
would be wrong.

The Mists cache holds `enUS` and `ruRU` only. That is deliberate and predates this: the
generator skips the other three for that build because `GetProfessions` there hands back a skill
line id directly, so nothing has to be looked up by name, and wago serves that build slowly
enough to time out.

### Transmutes share one cooldown

The client puts every alchemy transmute on a single shared timer: doing one puts all of them
away together. So an alchemist who knows five transmutes has five recipe records that all come
back at the same moment, and Family groups them into one — which is why the crafting column is
headed **Alchemy** and never the name of whatever was transmuted last.

Confirmed from play 2026-09-05, and worth writing down because the code that produces that
heading looks arbitrary without it: `Cooldowns:Crafting` names a group after its one recipe and
after the profession where several share a timer, and for alchemy the second branch is the only
one an established character ever takes.

The first branch is not dead: mooncloth is one recipe with one timer, and so is an alchemist who
has learned a single transmute so far. There the recipe's own name is the more useful heading,
which is what it gets.

### A hunter's stable, and a warlock's demon, measured on Era and Burning Crusade 2026-09-05

Two questions were asked of the client because the answers decide whether backlog entries 9 and
10 can be built at all. Both came back clearly, and both came back with something in them that
nobody would have guessed.

**The stable answers with the door shut, and slot 0 repeats slot 1.**

    /run for i=0,4 do local icon,name,level,family = GetStablePetInfo(i)
        print(i, tostring(name), tostring(level), tostring(family)) end

    TBC   0 Ranghesante 70 Ravager   1 Ranghesante 70 Ravager   2 nil
          3 Pallazza 60 Owl          4 nil
    Era   0 Spòstati 60 Gorille      1 Spòstati 60 Gorille      2 Palla 60 Chouette
          3 Alberto 60 Loup          4 nil

So the names, levels and families are all there without the stable being open, which was the
question. Three things follow that are not obvious:

- **Index 0 and index 1 are the same pet**, on both clients, with the same name, level and
  family. Anything that walks 0 to 4 and lists what it finds reports one pet twice. Which of the
  two indices *means* the current pet is not settled by this measurement and does not need to be:
  the pets are what is wanted, so the list is de-duplicated rather than indexed.
- **A nil slot is a gap and not the end.** TBC answers for 0, 1 and 3 with 2 empty, so a walk
  that stops at the first empty slot loses Pallazza. This was measured on 2026-09-04 as well and
  is the reason the earlier probe was run at all.
- **`GetNumStablePets` does not exist** on either client, measured 2026-09-04. The count comes
  from walking, which is why the two points above matter.

There is **no id anywhere in this answer** - icon, name, level and family, and nothing else. A
pet is therefore the one thing in Family that can only be stored under its name, and the name is
the player's own word in the language of no client at all. §2.1 is not being set aside; there is
nothing to set it aside for.

**The demon's book exists only while the demon is out.**

    /run local n, texture = HasPetSpells() print(tostring(n), tostring(texture))

    with a demon summoned    4  DEMON
    with none                nil nil

Identical on Era and Burning Crusade. So a warlock's per-demon abilities cannot be read on
demand at all: they can only be recorded at the moment that demon is summoned, and a record of
all of them is something Family accumulates over time rather than reads in one go. That is a
constraint on the feature rather than an obstacle to it, and it is the same shape as a
profession's recipe list, which is only readable while its window is open.

Backlog entry 10 spent its first probe on `GetSpellTabInfo` and found four tabs, all of them the
character's own - *Demonology* is the warlock's talent tree and not the demon's book. This is the
right door.

### The pet book is the creature's, and the creature has an id, measured on Era and Burning Crusade 2026-09-07

The previous section settled *when* a pet's book can be read. These two probes settle *what is
in it* and *what the thing holding it can be filed under*, which is what backlog entry 9's
abilities half and entry 10 both need before a single byte is stored.

    /run local n,t=HasPetSpells() print(n,t,UnitCreatureFamily("pet"))
        for i=1,(n or 0) do local nm=GetSpellBookItemName(i,"pet")
        local _,id=GetSpellBookItemInfo(i,"pet") print(i,nm,id) end

    /run print(UnitCreatureFamily("pet")) for i=1,3 do local n,r=GetSpellBookItemName(i,"pet")
        print(i,n,tostring(r),tostring(GetSpellBookItemLink and GetSpellBookItemLink(i,"pet"))) end

Run on a hunter and on a warlock, on both clients, with each of two creatures out:

| Client | Creature | `HasPetSpells` | `UnitCreatureFamily` | creature id in `UnitGUID("pet")` |
|---|---|---|---|---|
| Era | Gorilla | 9 PET | Gorilla **9** | 6516 |
| Era | Owl | 10 PET | Owl **26** | 7456 |
| Era | Succubus | 4 DEMON | Succubus **17** | 1863 |
| Era | Imp | 4 DEMON | Imp **23** | 416 |
| TBC | Ravager | 12 PET | Ravager **31** | 16934 |
| TBC | Owl | 11 PET | Owl **26** | 1997 |
| TBC | Voidwalker | 4 DEMON | Voidwalker **16** | 1860 |
| TBC | Imp | 4 DEMON | Imp **23** | 416 |

**Each creature's book is its own.** Succubus and Imp share not one line; Voidwalker and Imp
share not one line. That is entry 10's premise measured rather than assumed. A hunter's book is
the **pet's** and not the character's in the same way: the trainable ranks (Arcane, Fire, Frost,
Nature and Shadow Resistance, Great Stamina, Natural Armor, Growl) sit beside abilities that
belong to the family and to no other - Thunderstomp on the gorilla, Claw and Screech on the owl,
Bite, Gore and Dash on the ravager. So the abilities half of entry 9 is recorded **per pet**,
not per hunter.

**`UnitCreatureFamily` answers with two values, and the second is a number.** The family name is
the reader's own word - the Era stable in the section above says *Gorille*, *Chouette*, *Loup* -
but the number beside it is the same on both clients for the same family: Owl is 26 on Era and on
TBC, Imp is 23 on Era and on TBC. That is the language-free identity §2.1 asks for, and it is the
creature's family rather than the creature. It only answers for the creature that is **out**: the
stable's fourth return is the localised family name and no number, so a stabled pet is matched to
a family id only once that pet has been summoned at least once.

**The GUID carries a creature id** in its sixth field, and for a demon it is the whole answer:
the Imp is 416 on both clients, the Voidwalker 1860, the Succubus 1863 - one creature, one id, no
language in it. For a hunter's pet it identifies the **tamed creature** and not the family: the
owl is 7456 on Era and 1997 on TBC because they are two different NPCs of family 26.

**The number printed beside each ability is not a spell id, and nothing may be filed under it.**
It is `select(2, GetSpellBookItemInfo(i, "pet"))`, and the readings say what it is not:

- The values are three orders of magnitude above the spell id range on these builds -
  Growl 3238017609, Arcane Resistance 16801713, Lesser Invisibility 2164268734.
- It moves with the **rank**. *Natural Armor* is 16801846 on the gorilla, 16801845 on the Era
  owl and 16801771 on the TBC ravager's neighbour; *Fire Shield* is 2164272635 on the Era imp
  and 2164272634 on the TBC imp, and the second probe shows why - the Era imp knows Fire Shield
  **Rank 5** and the TBC imp **Rank 4**.
- It is stable where the ability and the rank are: Growl is 3238017609 wherever it appears, and
  Firebolt 3238014450 on both imps.

Whatever the number encodes - the pet bar's own ordering and flags is the shape it has, and that
is a guess and stays one - it is not an identity that survives a build, and a record filed under
it would be a record filed under a rank. Entry 9 already lost one probe to reading the icon and
calling it a name; this is the same mistake wearing a bigger number.

**What names an ability, then, is a name and a rank, both in the reader's language.**
`GetSpellBookItemName(i, "pet")` answers with two values, and the second is the rank as printed:

    Era  hunter, Owl       1 Arcane Resistance  Rank 2    2 Claw   Rank 8   3 Fire Resistance Rank 2
    Era  warlock, Imp      1 Blood Pact  Rank 5   2 Fire Shield Rank 5   3 Firebolt Rank 6
    TBC  hunter, Ravager   1 Arcane Resistance  Rank 3    2 Avoidance  Passive   3 Bite Rank 9
    TBC  warlock, Imp      1 Blood Pact  Rank 5   2 Fire Shield Rank 4   3 Firebolt Rank 6

A passive answers *Passive* in the same slot, so the second value is a word and not a number, and
both words are localised.

**That question was asked and half-answered the same day.** Run with a creature out on each
client:

    /run print(type(GetSpellBookItemLink), type(GetSpellLink))
        local a,b,c = GetSpellBookItemInfo(1,"pet") print(a,b,c)
        print(GetSpellLink and GetSpellLink((GetSpellBookItemName(1,"pet"))))

    Era   nil  function   PETACTION 16801713 nil
    TBC   nil  function   PETACTION 16801716 nil   [Arcane Resistance]

Three things came back, and they do not all point the same way:

- **`GetSpellBookItemLink` does not exist on either client** - `type` is *nil*, not *function*.
  So the pet book has no link door at all, and the *nil* the previous probe printed was the
  guard rather than an answer. There is no id to be had from the book itself.
- **`GetSpellBookItemInfo(i, "pet")` answers `PETACTION` and then that number**, with nothing
  in the third return. The first value names what the second one is: a pet **action**, which is
  the bar rather than the spell. And the number moved again for the same ability at a different
  rank - Arcane Resistance is 16801713 where the Era pet knows Rank 2 and 16801716 where the TBC
  pet knows Rank 3 - which is the third independent reading saying it carries the rank.
- **`GetSpellLink` exists on both, and only Burning Crusade resolves a pet ability by name.**
  TBC answered `[Arcane Resistance]`; Era answered nothing for the same name on the same kind of
  probe. Why the two builds differ is not measured and is not guessed here.

**One line is still owed, and it is the last one.** The chat window shows a link's text and not
its `spell:<id>`, so the id TBC may be holding has not actually been read yet, and Era's *nothing*
has to be asked a second way before it counts as *no id anywhere*. Run once per client, any
creature out:

    /run local n = GetSpellBookItemName(1,"pet") local l = GetSpellLink(n)
        local _,_,_,_,_,_,id = GetSpellInfo(n)
        print(n, l and (l:gsub("|","||")) or "no link", tostring(id))

The `gsub` doubles the pipes so the raw link prints instead of rendering, and `GetSpellInfo`'s
seventh return is asked separately because a name that will not make a link may still make an id.

**Burning Crusade answered, and it answered with an id.**

    TBC   Arcane Resistance   [Arcane Resistance]   27350

So `GetSpellInfo(<pet ability name>)` hands back a spell id on that build even though the book
itself has no link door. Two things are still not known and neither is a detail:

- **Era has not been run.** Its `GetSpellLink` said nothing for the same name, and whether its
  `GetSpellInfo` says nothing either is the whole difference between *stored by id* and *stored
  by name and language*.
- **Whether the id is the pet's rank or some other one.** The lookup was by **name**, and a name
  is shared by every rank of an ability - the TBC pet knows Arcane Resistance **Rank 3** and
  nothing in this reading says 27350 is that rank rather than the first one the client found.
  An id that names the ability but not the rank is still worth having; an id assumed to carry a
  rank it does not would put a Rank 1 in a record that read a Rank 3.

One line settles both, run on **each** client with any creature out:

    /run local n,r = GetSpellBookItemName(1,"pet")
        local _,_,_,_,_,_,id = GetSpellInfo(n)
        local r2 if id then local _,rr = GetSpellInfo(id) r2 = rr end
        print(n, r, tostring(id), tostring(r2))

If the fourth value matches the second, the name lookup lands on the rank the pet actually knows
and an ability is one id. If it does not, the id is the ability and the rank stays the word the
book printed.

**Era answered, and it answered with nothing.**

    Era   Arcane Resistance      nil

The middle value came back empty rather than the words *no link* the probe prints for a nil, so
Era's `GetSpellLink` most likely answers with an empty string rather than with nothing at all -
a detail, and not the one that decides anything. **The id is nil.** The same call that hands
Burning Crusade 27350 for Arcane Resistance hands Era nothing, for the same ability, read out of
the same kind of book, on the same probe.

**That settles the shape of the record, and the client that says less decides it:**

- A pet or demon **ability** is stored as the **name and the rank word the book printed, with the
  locale it was read in** - the shape a profession's recipe list already uses, and for the same
  reason.
- The **creature** is stored under the family id from `UnitCreatureFamily`, and a demon
  additionally under the creature id in its GUID. Those are ids and they are used as ids.
- §2.1 is not being set aside at the ability level: there is nothing to set it aside for on Era,
  and half an identity is worse than none. A record filed by id where the writer ran Burning
  Crusade and by name where they ran Era could not be compared with itself, which is exactly what
  a Wide Family link asks of it - and §6 forbids merging a linked family's data to hide the seam.
  TBC's 27350 is therefore **read and not used**.
- The rank question the previous probe raised - whether a name lookup lands on the rank the pet
  actually knows - never has to be answered, because nothing is filed under that id.

There is a door left, and it is not opened here: `wago.tools` holds the spell tables for every
build, so a generated table mapping a pet ability's name **in each locale** to its id is possible
the same way `tools/recipe-cooldowns.py` and the mount tables are. It would buy one thing only -
abilities read on Era becoming comparable with abilities read anywhere else - and it costs a
generated table per locale. It is worth revisiting only if a Wide Family panel actually wants to
line two hunters' pets up side by side; until then the name and its language are what crosses.

**The reader's side, measured 2026-09-07 with no creature out at all:**

    /run print(GetSpellInfo(27350))

    TBC   Arcane Resistance   nil   136096   0   0   100   27350
    Era   (nothing)

Two readings, and both matter.

- **A spell id needs no pet, no walk and no cache.** TBC named 27350 with the stable shut, which
  is `Names:Spell` behaving exactly as its comment says it does - the client answers about any
  spell id straight away, which is why the spellbook is stored as ids alone. So the login walk
  has nothing to do here in either direction: it exists because an **item** must be loaded before
  it can be named, and a spell must not.
- **The id is the rank's, and it is that build's.** Era does not know 27350 at all - it is the
  Burning Crusade rank of Arcane Resistance and Era has its own - so an id read on one build is
  not a word the other build can say. Anything generated for this has to be generated per build,
  the way the recipe cooldowns already are.

Note also that `GetSpellInfo` answered the **rank as nil** for the id, where the pet book answered
*Rank 3* for the name. So an id names the ability and not the rank, and a rank that is to reach a
reader in the reader's own language is a separate question from this one - the digit is in the
word the book printed and `tools/game-words.py` is where the game's own word for *Rank* would come
from.

**What Alberto is asking of this, stated plainly: a thing stored in language 1 must be read in
language 2 by a language-2 client.** Against that requirement the three shapes stand like this:
carrying the id where the client gives one satisfies it on Burning Crusade and not on Era; a
generated per-locale table satisfies it everywhere and costs a table per locale per build; and the
name alone satisfies it nowhere. Before either is built there is one more door to try, because it
would make the id available on Era at the moment of writing and cost nothing at all - the tooltip,
which is a different reader of the same book:

    /run local t = GameTooltip t:SetOwner(UIParent,"ANCHOR_NONE")
        print(type(t.SetSpellBookItem), type(t.GetSpell))
        if t.SetSpellBookItem then t:SetSpellBookItem(1,"pet") end
        if t.GetSpell then print(t:GetSpell()) end

The types are printed first and separately, per L-062. If `GetSpell` answers with an id for a pet
book slot on Era, the whole question closes: the writer records the id its own client gave it, on
every build, and the reader's client says it in the reader's language with no table anywhere.

**The door opened. Era, with the pet out:**

    /run local t=GameTooltip t:SetOwner(UIParent,"ANCHOR_NONE")
        print(pcall(t.SetSpellBookItem,t,1,"pet"))
        local n,i=t:GetSpell() print(tostring(n),tostring(i),t:NumLines())

    book   true false    Arcane Resistance   24497   2
    bar    true false    nil                 nil     2

- **`GameTooltip:GetSpell()` hands back a spell id for a pet book slot on Era** - 24497 for the
  Arcane Resistance the book calls *Rank 2*. The client had the id all along; the spell book's own
  calls are simply the wrong readers to ask for it.
- **The pet bar is not the same door.** `SetPetAction(1)` builds a two-line tooltip and answers
  `nil, nil` - it draws the ability and exposes no spell. So the book, always, and never the bar.
- Both calls survived; the `false` beside each `true` is the setter's own return value, not a
  failure. The probe was run with `pcall` precisely so those two could not be confused, which is
  the same lesson as the guarded call in L-062 wearing a different hat.

**So an ability is recorded by id on every build, and the requirement is met.** The writer asks
its own client through a tooltip and stores what it gets; the reader turns that id into the
reader's own language with `Names:Spell`, straight away, no summon and no walk. The word the book
printed is kept **beside** the id rather than instead of it - which is the recipe pattern
exactly - because a build does not always know another build's ids: Era printed nothing for TBC's
27350, and in that case the word is what is drawn, the same fallback every shared id already has.

Two things this hands to whoever builds it:

- It must go through `Family:ScanTooltipLine`'s tooltip - `FamilyScanTooltip` in
  `addons/Family/Core.lua`, made once and never shown - and never through `GameTooltip`, which
  belongs to the player and is on screen. The existing helper returns a **line of text**; reading
  a spell wants a sibling that aims the same tooltip and answers `tip:GetSpell()` instead.
- The rank is still the book's word. The id is the rank's - Era's Rank 2 is 24497 and TBC's Rank 3
  is 27350 - so a reader who is shown the ability's name from the id and the rank from the word is
  being shown one translated half and one untranslated one. Whether the rank is drawn at all is a
  panel question, and the digit inside the word plus `tools/game-words.py` is the way to draw it
  translated if the answer is yes.

**Mists is a third shape, measured 2026-09-07, and it puts something else in the book.**

    15 PET Cat 2
    1 Assist 100663299        2 Attack 117440514      3 Avoidance 16842436
    4 Claw 3238019515         5 Combat Experience     6 Dash
    7 Defensive 100663297     8 Follow 117440513      9 Growl 3238005337
    10 Heart of the Phoenix   11 Move To 117440516    12 Passive 100663296
    13 Rabid                  14 Spiked Collar        15 Stay 117440512

    Cat Beast Pet-0-4468-1-18-42718-0100B7435A
    nil function   PETACTION 100663299 nil

What agrees with the older clients: `HasPetSpells` answers a count and `PET`, the family number
is there beside the word (Cat is 2), the GUID's sixth field is the creature (42718),
`GetSpellBookItemLink` does not exist, and `GetSpellBookItemInfo` names its own second return
`PETACTION`.

What does not, and it matters to anything that reads this book:

- **The pet's commands and stances are in the book.** *Assist*, *Attack*, *Defensive*, *Follow*,
  *Move To*, *Passive* and *Stay* are seven of the fifteen rows, and none of them is something a
  pet has learned - they are the buttons on the pet bar. The Era and Burning Crusade books
  measured above hold none of them. So a reader that records what the book holds records seven
  commands per pet on Mists and calls them abilities.
- **The second value of the name call is not a rank there.** It answers *Pet Stance* for Assist
  and *Pet Command* for Attack, where Era answers *Rank 2* - and *Passive* for Avoidance, which
  the older clients answer too. Mists has no ability ranks at all.

**One line is owed before this can be filtered honestly**, because the obvious filters are both
guesses: the rank word is the reader's language, and the `PETACTION` number is a bar position
nothing may be filed under. What is worth measuring instead is whether a command has a **spell id**
at all. Run on Mists with a pet out:

    /run local t=GameTooltip t:SetOwner(UIParent,"ANCHOR_NONE") for _,i in ipairs{1,2,4,9} do
        t:ClearLines() pcall(t.SetSpellBookItem,t,i,"pet")
        local n,id=t:GetSpell() print(i,tostring(n),tostring(id)) end

Slots 1 and 2 are a stance and a command, 4 and 9 are real abilities. It answers two questions at
once: whether the tooltip door that gives the id on Era and Burning Crusade exists on Mists at
all - nothing above says it does - and whether a command comes back without one, which would make
*has an id* the filter, in the client's own terms rather than in English.

**And the doors are the other way round on Mists.** Measured the same day, with a pet out:

    SetSpellBookItem(1, "pet")   true   nil    nil    2 lines
    SetPetAction(1)              true   Growl  2649   4 lines

On Era the book answered with an id and the **bar** answered nothing; on Mists the bar answered
`Growl, 2649` and the book slot answered nothing. Two readings, opposite ways round, and neither
build's door can be assumed to be the other's.

The book slot asked there was **slot 1, which is *Assist*** - a stance, not an ability - so that
nil is two possible facts at once: the book door may not work on Mists, or it may work and have
nothing to say about a bar command. Which of the two it is decides whether *has an id* can be the
filter that keeps the seven commands out of a Mists record, so it is asked directly, on a slot
that holds a real ability:

    /run local t=GameTooltip t:SetOwner(UIParent,"ANCHOR_NONE") for _,i in ipairs{2,4,9} do
        t:ClearLines() pcall(t.SetSpellBookItem,t,i,"pet")
        local n,d=t:GetSpell() print("b",i,tostring(n),tostring(d)) end

Slot 2 is *Attack*, a command; 4 is *Claw* and 9 is *Growl*. And the bar, whose own indexing is
not the book's - Growl is book slot 9 and bar slot 1 - because if the book door is shut on Mists
then the bar is the only lane there is and what it is indexed by has to be known before anything
is written through it:

    /run local t=GameTooltip t:SetOwner(UIParent,"ANCHOR_NONE") for i=1,10 do
        t:ClearLines() pcall(t.SetPetAction,t,i)
        local n,d=t:GetSpell() print("a",i,tostring(n),tostring(d)) end

**Both answered, 2026-09-07, and together they settle the whole thing.**

    b 2  nil    nil       a 1  Growl 2649                a 6  nil nil
    b 4  Claw   16827     a 2  Claw 16827                a 7  nil nil
    b 9  Growl  2649      a 3  Dash 61684                a 8  nil nil
                          a 4  Heart of the Phoenix 55709   a 9  nil nil
                          a 5  Rabid 53401               a 10 nil nil

- **The book door is open on Mists too.** It was slot 1 being *Assist* that answered nothing,
  not the door being shut. So the tooltip aimed at a book slot is the one lane on all three
  clients, which is what `Scanners/Pets.lua` reads through.
- **A command has no spell id and an ability has one.** *Attack* at book slot 2 answers nothing
  where *Claw* answers 16827 and *Growl* 2649. That is the filter, said by the client in its own
  terms: no English, and nothing filed under a `PETACTION`. A book where **nothing** came back
  identified is a different case and keeps its words - that is a client whose tooltip will not
  describe a pet book at all, and dropping every row there would blank a hunter's page rather
  than leave it a language behind.
- **The bar is not a substitute for the book**, and this is why it is not used even on the build
  where it answers first. The bar holds five: Growl, Claw, Dash, Heart of the Phoenix, Rabid.
  The book holds eight once the commands are filtered - those five and *Avoidance*, *Combat
  Experience* and *Spiked Collar*, which are passives and are on no bar. Reading the bar would
  have quietly lost three real abilities per pet and looked entirely correct doing it.

### The Craft window says three things about a row that were being thrown away, measured 2026-09-07

Reported from play: a hunter's Beast Training list on the spellbook page drew five rows all
called *Arcane Resistance*, with no rank and no tooltip on any of them. All three of the missing
pieces were in the window. Asked with Beast Training open on Burning Crusade:

    /run print(GetNumCrafts(), type(GameTooltip.SetCraftSpell))
        for i=1,4 do print(i, GetCraftInfo(i)) end

    81  function
    1 Arcane Resistance  Rank 3  none  0  nil  45  40
    2 Arcane Resistance  Rank 4  none  0  nil  90  50
    3 Arcane Resistance  Rank 5  none  0  nil  105 60
    4 Avoidance          Rank 1  none  0  nil  15  30

- **The second return is the rank**, in the reader's own language, and it is what the window
  draws under the name. `Scanners/Professions.lua` was discarding it with a `_`.
- **The two numbers at the end are a cost and a level**, and the readings say which is which
  without anything being assumed about the call's argument order: for ranks 3, 4 and 5 the second
  number is 40, 50 and 60 - a ladder - while the first is 45, 90, 105.

And the row's id comes from a third reader, because a pet ability makes no item and answers
neither `GetCraftRecipeLink` nor `GetCraftItemLink`:

    /run local t=GameTooltip t:SetOwner(UIParent,"ANCHOR_NONE") for _,i in ipairs{2,3} do
        t:ClearLines() print(pcall(t.SetCraftSpell,t,i))
        local n,d=t:GetSpell() print(i,tostring(n),tostring(d),t:NumLines()) end

    2  Arcane Resistance  24501
    3  Arcane Resistance  27052

`GameTooltip:SetCraftSpell` exists and answers, which is the same door the pet's own book turned
out to have. The ids continue the series the book gives for the rank the pet already holds -
24500 for Rank 3 out of the book, 24501 for Rank 4 and 27052 for Rank 5 out of the trainer's
window - so the two readers agree about what an ability is.

The tooltip is asked **only where both links said nothing**, so an enchanting row keeps the id it
already had and nothing about the professions changes.

**What the creature has left to spend, measured 2026-09-07.** `GetPetTrainingPoints` exists and
answers two numbers, and which is which needed a second pet to settle: the first asked answered
**300 300**, which is symmetric and says nothing. A Burning Crusade pet with seventy-seven points
free answered **350 273**, and its window said 77. So the first is the **total**, the second is
**spent**, and what is left is the difference - which is the only one of the three a player can
act on, and the one Family draws. Mists has no training points at all; a nought there is a claim
about a system that build does not have rather than a pet with none left, so nothing is recorded.

**The window prices what the creature that is out can learn, and nothing else.** Reported from
play with the window open beside Family's own page: a cat is shown a cost against every rank of
Claw and none at all against Bite, Gore, Charge or Growl - the abilities of families it does not
belong to - and `GetCraftInfo` answers nought for exactly those rows. So a blank cost is the
client's own answer about this creature rather than a gap in the reading, and it moves when a
different creature is summoned.

Those same rows are the ones the client will not build a tooltip for, which is how they came to
carry the wrong id: see L-063.

**And the window itself has an id, measured 2026-09-07 with Beast Training open on Era:**

    /run local a,b,c,d,e,f,id=GetSpellInfo(GetCraftName()) print(GetCraftName(), tostring(id))

    Beast Training   5149

`GetCraftName` answers with the word the window is titled in whatever language the client is set
to - *Dressage des betes* on a French one - and the client will turn that word into the id of the
spell that opens it, because the window **is** a spell the character casts. So a craft window that
is not a profession is filed under 5149 rather than under either word, and the word is kept beside
the entries to be drawn as the heading.

**Burning Crusade closes the set, and disagrees with itself in a useful way.**

    /run local t=GameTooltip t:SetOwner(UIParent,"ANCHOR_NONE")
        pcall(t.SetSpellBookItem,t,1,"pet")
        local n,d=t:GetSpell() print(tostring(n),tostring(d))

    TBC   Arcane Resistance   24500

So the door is open on all three clients, which is the last thing `Scanners/Pets.lua` was
resting on and had not been shown.

And the number is **not** the 27350 the same client handed back for `GetSpellInfo("Arcane
Resistance")` earlier the same day. Both name the same ability; only one of them was asked about
the slot the pet actually holds. That is the caution written beside 27350 when it arrived -
*a name is shared by every rank, and nothing says this is the pet's rank rather than the first
one the client found* - turning out to have been worth writing: the name lookup lands on some
rank, and the tooltip reads the one in the book. Nothing was ever filed under 27350, so nothing
has to be undone; what it settles is that the tooltip is not merely *a* door but the *right* one.

### A creature's abilities against what it has spent, read 2026-09-09

`/family pettp` on a Burning Crusade hunter, for **Ranghesante**, a Ravager the client says has
spent **273** of **350** training points:

    Arcane Resistance Rank 3    45
    Avoidance Passive            -
    Bite Rank 9                 29
    Cobra Reflexes              15
    Dash Rank 3                 25
    Fire Resistance Rank 3      45
    Frost Resistance Rank 2     15
    Gore Rank 9                 29
    Great Stamina Rank 3        15
    Growl Rank 7                 -
    Nature Resistance Rank 2    15
    Shadow Resistance Rank 2    15

    10 priced, 2 with no price in the trainer's window, 0 the client would not name,
    and the priced ones come to 248.

**Two hundred and forty-eight of two hundred and seventy-three, and exactly two abilities
unpriced.** So the model holds as far as this can show it: *what a creature has spent is the sum,
over the abilities it holds, of the cost of the rank it holds* - and the twenty-five missing
belong to the two rows Family has never seen a price for. A model that was wrong in shape would
not land within one plausible pair of costs.

**Settled the same day, with the window open and the creature out** - the reading above left it
open whether the window prices a rank the creature *already holds*, because the crafts record
accumulates and the 45 might have been read before Rank 3 was learned:

    /run for i=1,GetNumCrafts() do local n,r,_,_,_,c,l=GetCraftInfo(i)
        if n=="Arcane Resistance" or n=="Growl" or n=="Avoidance" then print(i,n,r,c,l) end end

    51 Arcane Resistance Rank 1    5  20
    52 Arcane Resistance Rank 2   15  30
    53 Arcane Resistance Rank 3   45  40
    54 Avoidance Rank 1           15  30
    55 Avoidance Rank 2           25  60
    71 Growl Rank 1                0   1
    72 Growl Rank 2                0  10
    ...
    77 Growl Rank 7                0  60

**The window is a price list and not an offer.** Arcane Resistance Rank 3 is priced at 45 with the
creature holding Rank 3, so every rank is listed and priced whether or not it is already known.
Which makes the cost of what a creature holds readable at any time, and Family's price table a
current list rather than a memory.

**And Growl is free, at every one of its seven ranks.** That is the reading that mattered most,
because it was the one the old storage rule threw away: *nought is not stored* was written from a
profession's window, where the call answers nought for every row because there is no such column.
Beast Training answers nought for **some** rows and a real cost for others, and there the nought
is the client's own answer. So the rule is now decided across the window rather than row by row -
a window that priced nothing records no costs, a window that priced something keeps its noughts -
and Growl reads as *free* rather than as *never priced*.

**The arithmetic closes exactly.** 248 priced + 25 for Avoidance + 0 for Growl = **273**, which is
what the client said. So the creature holds Avoidance **Rank 2**, and the only reason Family could
not price it is that the pet's own book calls it *Passive* with no rank, and its id did not match
either of the window's two Avoidance rows. That is the one thing still open here, and it is a
question about an id rather than about the model.

**One number, two meanings, and only in the trainer's list.** A nought cost is *this row is free*
for Growl and *this creature cannot learn this row* for Charge, Scorpid Poison and Thunderstomp
shown to a Ravager - the same nought from the same call. The **Pets** page has no such doubt,
because a creature only holds abilities it could learn, so a nought against one of its own is
drawn as free. The Beast Training appendix draws nothing where it cannot tell.

**And the window has a state in which it prices nothing at all**, read the same day. Asked for
every row whose cost is nought:

    /run for i=1,GetNumCrafts() do local n,r,t,_,_,c,l=GetCraftInfo(i)
        if (c or 0)==0 then print(i,n,r,t,c,l) end end

    1  Arcane Resistance Rank 1  none 0 0
    ...
    81 Thunderstomp Rank 3       none 0 0

**All eighty-one rows, nought for the cost and nought for the level** - including the Arcane
Resistance rows that had answered 5/20, 15/30 and 45/40 twenty minutes earlier, and including the
rows the earlier reading priced at 25 and 15. The list is still there and every number in it is
gone, which is a different thing from a row the creature cannot learn and is what *the window
prices what the creature that is out can learn* looks like when there is nothing to price for:
**both numbers go to nought together, across the whole window.**

What put it in that state was not recorded and is worth knowing - no creature summoned and the
window no longer open are both candidates, and `GetNumCrafts` answering 81 says the list survives
either. It matters only for the narration, because nothing is lost when it happens: the
whole-window rule records no costs from such a reading, and the merge keeps every price an earlier
one found. Family now says so in the narration rather than leaving a record that did not change
looking like a reading that never happened.

**And then the same question asked with the window pricing, which settles it.** Every row whose
cost is nought, with the creature out and the window answering:

    3  Charge Rank 1          none 0 0     39 Scorpid Poison Rank 2  none 0 0
    5  Claw Rank 2            none 0 0     41 Screech Rank 1         none 0 0
    11 Dive Rank 3            none 0 0     48 Thunderstomp Rank 2    none 0 0
    ...                                    ...
    70 Growl Rank 1           used 0 1     74 Growl Rank 5           used 0 40
    71 Growl Rank 2           used 0 10    75 Growl Rank 6           used 0 50
    72 Growl Rank 3           used 0 20    76 Growl Rank 7           used 0 60
    73 Growl Rank 4           used 0 30    77 Growl Rank 8           used 0 70

**Two groups and no others, and the level tells them apart.** The families a Ravager is not -
Charge, Claw, Dive, Scorpid Poison, Screech, Thunderstomp - answer nought for the cost **and
nought for the level**. Growl answers nought for the cost against a real ladder, 1 to 70.

So: *a row the client has nothing to say about for this creature answers nought for both numbers
together; a row that is genuinely free answers nought for one of them.* Both numbers come from the
one call, which is what lets the second answer for the first, and it is the same shape as the
whole-window state above, where every row lost both at once.

The third return agrees - `none` against `used` - and is not what the rule is built on: it is
Blizzard's own enumeration and what its values mean here has not been read, while *this row states
no level* has a plain reading. Two independent answers agreeing is why this is written as settled
rather than as likely.

**What Family does with it.** A cost of nought is kept where the row states a level and dropped
where it does not, so the record holds Growl at nought and holds nothing at all for Charge. Both
the Pets page and the Beast Training appendix therefore draw a nought where they have one, because
a nought that reached the record means *free*. The two rules tried before this reading were both
wrong: *nought is never stored* lost Growl, which is what left a pet's points not adding up, and
*nought is stored wherever the window priced anything* would have recorded Charge as free for a
Ravager.

**Dismissing and re-summoning re-reads the window**, reported from play the same day - which is
the cheapest way to refresh what a creature's abilities cost.

#### A Beast Training row and the id it hands back are two different spells

Read 2026-09-09 on Burning Crusade, with a Ravager out and the window open, after the pet's spent
training points came to 248 against the 273 the client itself stated. The whole of the difference
was one ability:

    window row 53   Avoidance   Rank 1   15 points   level 30   tooltip id 35694
    window row 54   Avoidance   Rank 2   25 points   level 60   tooltip id 35698

    pet's own book  Avoidance   Passive                                   35698

    GetSpellInfo(35694)     Avoidance        GetSpellSubtext(35694)   Passive
    GetSpellInfo(35698)     Avoidance        GetSpellSubtext(35698)   Passive

So the two readings **do** meet on an id - the book's 35698 is the window's Rank 2 - and the join
Family needs is the plain one it already does everywhere. What refused it was the rank cross-check,
which asks the row's own rank word and `GetSpellSubtext` to be the same string and here got *Rank 2*
against *Passive*.

**They disagree because they are about two different spells.** The window row is the hunter's
*teaching* spell, which is ranked, and the id the tooltip hands back is the ability the pet ends up
holding, which is passive and says so. Alberto found the teaching spells listed separately -
Avoidance Rank 1 and Rank 2 as 35699 and 35700 - and the client says the same thing without being
asked: a row labelled *Rank 2* answering an id whose own subtext is *Passive* is one reading of each
of two spells, not two readings of one. Nothing here is taken from that listing; it named the shape
and the client confirmed it.

**Confirmed in play the same day, after the fix.** Ranghesante reads *273 of 273* over twelve
abilities, Avoidance among them at 25 under 35698, with none unpriced and none the client would not
name; Pallazza reads *300 of 300* over eleven. Two creatures and no residue on either.

**What Family does with it.** The rank cross-check now stands down for an ability whose rank call
answers the *same* word for every row of it - a reading that cannot tell Rank 1 from Rank 2 is no
evidence about either - and keeps refusing wherever the words differ, which is what keeps an id
naming Bite Rank 6 off the Bite Rank 9 row. Two rows at least, and a row whose id answers nothing
is passed over rather than counted as a different answer, because six of eight rows came back nil
from that call on the record the lane was first built from.

### What crosses a Wide Family link as a word, and cannot be translated

Read 2026-09-05, after Alberto asked whether a subzone is the only shared thing a reader sees in
somebody else's language. It is not, and the difference between the cases is worth having
written down.

Nearly everything Family shares carries an **identity** beside the word, and the reader's own
client turns the identity into the reader's own language. A hearthstone has `hearthID`, a race
has `raceFile` and `raceID`, a profession is a skill line id, a recipe carries a spell id and an
item id, and a logout zone has `zoneID`. In every one of those the word is a fallback for a
client that has never heard of the id - a Northrend area on an Era client - and not the thing
normally shown.

**Three shared things are words with no identity behind them:**

- **A subzone.** `GetSubZoneText` answers with a word, and the walk that turns a word into an id
  does not find it. **Measured 2026-09-05**, because the first version of this line asserted that
  no such mechanism existed - which was wrong: `Names:AreaFor` is exactly that mechanism, and it
  is what names a hearthstone and a quest category. Asked on a live French Era client standing in
  the Military Ward of Ironforge:

      sub  La Garde militaire  ->  nil

  So the word is in no area the client will name, and wago's Era `AreaTable` agrees - that export
  carries 1,212 rows and **no child of area 1537 at all**, Military Ward included. Not every
  subzone is like that: Eccebombo's was recorded as *Ironforge*, which **is** area 1537, so a
  subzone word that happens to name a zone would be found. Half a column translated by luck, at
  a twenty-thousand-id walk for each new subzone word and most of them coming back empty, is not
  a trade worth making - so this line stays as recorded, and now it stays that way for a measured
  reason rather than an asserted one.
- **A quest's objective lines.** Each is stored as the words of the client that read the log,
  because an objective has no id of any kind on these builds. The way out would have been to
  store only *done* per index and let the reader's own client supply the labels - and that is
  measured shut: `GetQuestObjectiveInfo(4289, 1, false)` answers **nil** on Classic Era for a
  quest the player is not on (2026-09-05). Whether the call is absent or merely silent makes no
  difference here; either way there are no labels to be had.
- **A quest's title**, and
- **the zone heading a quest is filed under**, both in the `quests` payload, both drawn as
  recorded by `UI:QuestLines`.

The two quest cases are unlike the subzone in the one way that matters: a quest **does** have an
id, recorded since 2026-09-05. What that buys turned out to be less than it looked, and the
measurement is in the next section.

The rest of what crosses is proper nouns - a character's name, a realm, a guild - which are the
same word in every language and are not a translation question at all.

### A quest's title is not in the client's tables at all, measured 2026-09-05

Alberto's question, on being told a sibling's quest cannot be named in the reader's language:
*wago does not give us the titles from the id? and the current client does not?*

Both halves asked rather than answered from memory.

**wago has no quest names, on any of the three pinned builds.** `QuestV2` is served for all
three and its columns are `ID,UniqueBitFlag` - an id and a flag, and no name in any locale:

| Build | `QuestV2` | `Quest` | `QuestLine` | `QuestInfo` |
|---|---|---|---|---|
| Classic Era 1.15.9.69109 | 200, 47,880 bytes, `ID,UniqueBitFlag` | 404 *Table not found* | 404 | 200, **166 bytes**, `ID,InfoName_lang,Type,Modifiers,Profession` |
| Burning Crusade 2.5.6.69110 | 200, 61,087 bytes, same columns | - | 404 | - |
| Mists 5.5.4.69078 | 200, 187,805 bytes, same columns | - | 404 | - |

`QuestInfo` is 166 bytes for the whole table: it names the *kinds* of quest - group, dungeon,
raid - and not the quests. So there is no file to ship, which makes this a different answer from
the hearthstone's. That one was a **trade** refused at 876 KB (L-020); this is not a trade at
all.

**`C_QuestLog.GetTitleForQuestID` and `GetQuestLink` answer only about a quest in the player's own
log.** The first probe of `GetQuestLink` on a quest the character was not on printed *nothing at
all* - the call raises rather than returning nothing, and the error landed before the `print`,
which is why a one-line probe with two arguments said less than it looked like it would.
`Family:TryCall` is what makes that a fallthrough in play rather than a broken panel.

**But the client will still describe the quest, and that was written here as a flat "it cannot"
for half an hour.** `GameTooltip:SetHyperlink("quest:<id>:<level>")` describes a quest the
character has never had, **in the reader's own language**. Alberto's screenshot is the
measurement: a level 5 French character hovering a sibling's level 58 quest, and the client
drawing *Les tablettes perdues de Mosh'aru* with its objectives under it. `Tooltip.lua` had been
asking that way since the day before, so Family's own screen was disproving the claim while it
was being made (L-057).

The form matters and is measured in `Tooltip.lua`: a bare `quest:84` answers **nought lines** and
`quest:84:20` answers three. So **the level is part of the question**, and a row with no level
recorded cannot ask it. The title is the first line.

So the two failing calls are not "the client cannot" - they are two calls that share one
precondition. `Names:Quest` now asks the tooltip as its third route, and every answer any route
gives is written down by id per language, because the tooltip is the expensive one and a store
turns it into one question per quest for the life of the account.

### `GetZoneText` does not answer with an area name, measured 2026-09-05

Found from play: a character who logged out in Ironforge on an English client kept reading
*City of Ironforge* on a French one, while the quest headings beside it translated correctly.

`Names:AreaFor` had done its job. The word is simply **not in `AreaTable`**:

- Era 1.15.9.69109 `AreaTable`, enUS: 1,212 rows, highest id **16,394** - which is the same
  ceiling `Names.lua` measured against the live client, so the table and the client agree and
  the grep is decisive. **No row contains the string "City of"**, in any position. Ironforge is
  id 1537, named `Ironforge`; 809 is `Gates of Ironforge`.
- The same table in frFR names 1537 `Ironforge` too - untranslated, exactly as `tools/areas.py`
  predicted of Era's French - and 809 `Portes d'Ironforge`.
- `UiMap` for the same build names Ironforge id **1455**, and also has no *City of*.
- `Map` for the same build has no row mentioning Ironforge at all.

Meanwhile `GetSubZoneText` in the same spot answered `Ironforge`, which **is** area 1537.

So the two calls read different tables, and only the subzone's answer is an area name. Every
other caller of `AreaFor` is safe - `GetBindLocation` returns an area name and a quest log's
headings are area names, which is why the hearthstone and the quest categories both translate -
and `GetZoneText` is the one source that is not. A word that is not in the table costs a full
20,000-id walk and is then remembered as absent, so it is paid once and answers nothing for
ever.

**The live client, probed from Ironforge on French Era 2026-09-05:**

    GetZoneText()                      Cité d'Ironforge
    GetRealZoneText()                  Cité d'Ironforge
    GetSubZoneText()                   Ironforge
    C_Map.GetBestMapForUnit("player")  1455
    C_Map.GetMapInfo(1455).name        Ironforge

So `GetRealZoneText` is not a second chance - it answers the same word, and that word is in no
area table. The map id **1455 agrees with `UiMap` character for character**, which is what makes
it usable: an id the reader's own client turns into the reader's own word, with no search at all.

Two things this does **not** settle, both of which the code degrades safely around:

- Whether it exists on Burning Crusade and Mists. Guarded on the symbol being there, and the
  area-id walk is still the path where it is not.

**And it does not answer during `PLAYER_LOGOUT`.** Measured the only way it can be, which is why
it was shipped as a live call first: deploy, log out somewhere known, log back in, and read the
record.

    Cité d'Ironforge  map nil  loc frFR

Milionario logged out in the Military Ward of Ironforge, French Era. `GetZoneText` and
`GetSubZoneText` both still answered there - measured on 2026-09-05 and still true - and the map
call did not. The map system is gone by then.

There is no `/run` that reaches this: there is no frame left to print to. It has to be read off
what was saved, which makes it the shape of thing that gets shipped, watched and corrected rather
than probed first.

So the map is read **while playing** - on `PLAYER_ENTERING_WORLD` and the three `ZONE_CHANGED`
events - and the last answer is kept with the zone word it was the answer for. At logout the live
call is tried first and the kept one is used only if its word matches the place being recorded: if
the player moved after the last reading, a map id from somewhere else is worse than none, and the
area id carries it instead.

And note the wording changes with the source: `GetZoneText` says *Cité d'Ironforge* where the map
is called *Ironforge*. That is why the recorded word wins for a reader whose own client speaks the
language it was written in - the rule `Names:Recipe` and `Races.lua` already keep.

### The item a recipe makes, back to the spell that makes it, generated 2026-09-05

Reported from play: CTRL swapped a recipe's tooltip on leatherworking and did nothing on cooking
or first aid, on Classic Era. Two reasons, and the second is the one that would have kept it
broken.

`RecipeTeaches` and `RecipeMakes` are both keyed by the **recipe item** - the pattern in
somebody's bags - so inverting them reaches a recipe an item taught and not one a trainer taught.
And both are built from the **primary** skill lines alone: `SkillLine.CategoryID` 11. **Cooking
is 185 and First Aid is 129, and both are category 9**, so no amount of inverting was ever going
to reach them.

So a third table, `Family.RecipeMadeBy`, generated by the same tool from the same rows read the
other way round: `SpellEffect` effect 24 (CREATE_ITEM) with `EffectItemType`, kept only where a
profession skill line teaches the spell, with the lowest spell id winning where two make the same
thing.

| | |
|---|---|
| Products named | **1,406** on Classic Era |
| Of those, cooking and first aid | **104** |
| Size | **26 KB** added to `RecipeTeaches.lua`, against an addon of 2,120 KB |
| Builds emitted | **Classic Era only** |

The narrowing to profession-taught spells is what keeps it small and right: Era has 2,381
CREATE_ITEM effects and 2,217 distinct products, and most of the difference is quest rewards,
containers and consumables that no profession makes. Unfiltered it measured 41 KB.

**Era only, because it is the only client that needs it.** A trade skill record there carries the
product and no spell; Mists answers with both - 8 smelting recipes with a spell id and an item id
each - and Burning Crusade behaves as Mists does, confirmed from play the same day. All three
builds would be about 130 KB to say something two of them already say.

### Quest categories that are not zones — `QuestSort`, generated 2026-09-05

The last word left untranslated on a page where everything else had crossed: *Démoniste*, sitting
between *Un'Goro Crater* and *Sunken Temple* on an English client, with *Cuisinier*, *Forgeron*
and *Secourisme* behind it on other characters.

A quest log groups by heading and Family records the heading as a word. Most headings are zones,
and the log has carried a zone id per heading since earlier the same day. The rest had nothing.

**They are not the professions table wearing a different hat**, which is the thing to know before
reaching for `SkillLines.lua`: the French for Cooking is *Cuisine* and the heading says
*Cuisinier*. They come from `QuestSort`, which is its own table.

| | |
|---|---|
| Rows | 36 on Era, 35 on Burning Crusade, 55 on Mists — **52** after merging and dropping the dead |
| Per locale | under 1.1 KB of CSV |
| Shipped | **10 KB** of Lua, all five languages |
| Examples | 61 Warlock / Démoniste / Hexenmeister · 304 Cooking / Cuisinier · 101 Fishing / Pêcheur |

Blizzard leaves retired rows in place named `REUSE - old wailing caverns`; those five are
dropped, from the English, which is where the note is written.

Every build's names go into one row per id rather than being kept apart, which is the opposite of
what `RecipeTeaches` does and for a reason: **nothing records one of these**. A reader is handed
whatever word the recording client wrote and asks which row holds it, so a sort renamed between
builds wants both words finding the same row — which is exactly what a family playing across two
clients needs. It also means this works on records written before it existed, with nothing new
crossing a link.

This is the case the 876 KB of area names was not (L-020): five languages, and it costs 10 KB.

### How fast a mount goes, generated 2026-09-06

Asked for from play as *has this alt got a mount, and is it the fast one*. Family already recorded
both halves and could read neither: the spellbook is a list of spell ids and the bags a list of
item ids, and nothing said which of them was a horse.

**Read from `SpellEffect`**, effect 6 (apply aura) with aura 32 (mounted speed), the percentage in
`EffectBasePoints`, and the item that casts each from `ItemEffect`.

| | |
|---|---|
| Mounts named | **307** across the three builds |
| Carried as an item | **261** |
| Size | **10.5 KB** (`MountSpeeds.lua`) |
| Speeds | 60% and 100% carry almost all of it; 150, 185, 200 and 300 exist |

**The builds do not store the percentage the same way**, and that is the whole reason they looked
as though they disagreed about seven mounts: Era and Burning Crusade keep 59 for +60%, Mists keeps
60. Applied per build, they agree exactly - one spell out of 307 still differs and the faster
reading wins, so a mount is never reported slower than it is.

**Anything under 50% is dropped.** Those are not mounts: the values that fall out are 0, 1, 10,
15, 20, 25 and 40, other things wearing the same aura. No mount has ever been slower than 60%.

**Keyed on the mount and never on the riding skill**, which Classic Era makes obvious. Alberto's
description of that build, confirmed against `SkillRaceClassInfo`: the riding skill is a
*permission* whose value is always 300 once held; a character can hold several of them, which is
what lets a human exalted with Darnassus buy a tiger; and a paladin's or a warlock's mount is a
class spell that teaches no riding skill at all. A column reading the skill would print *cannot
ride* over a paladin on a horse. From Burning Crusade the skill becomes the ladder - skill line
762 has four rungs chained by `SupercedesSpell`, at ranks 75 and 150 and then the two flying ones
- but the mount is still the evidence, so one key answers on every build with no branch in it.

The client's own table says the same about Era's shape: every riding line there has **two rows in
`SkillRaceClassInfo`**, one `SkillTierID` for the race that owns the mount and another for
everybody else. Cooking, fishing and first aid have one.

**Flying is a second number on the same spell**, not a faster mount, and reading only the first is
what a report from play caught the same day: a character with an Ebon Gryphon and an epic ground
mount showed *100%* and said nothing about being able to fly. Aura **207** carries it.

| Build | Flying spells | Speeds |
|---|---|---|
| Classic Era | **0** | none - there is no flying in vanilla |
| Burning Crusade | 49 | 60% (11), **280%** (28), **310%** (8) |
| Mists | 12 | 150%, 280%, 310%, 500% |

Ebon Gryphon is spell 32239 and measures **+60% on the ground and +60% in the air** - the Expert
tier, which matches a riding skill of 225. The 310% rows are the rare Burning Crusade mounts.

**A druid's flight forms are not in this**, and the tables looked at so far do not have the number
either. Spells 33943 and 40120 on Burning Crusade carry aura 36 (shapeshift), aura 77 and aura
**201 (enable flight)**, with no speed in the spell; `SpellShapeshiftForm` has the two forms - 29
*Flight Form* and 27 *Flight Form, Epic* - with `MountTypeID` 0 and no speed column at all. The
number is in the spell's own description text, which Alberto's tooltip shows as **60%** on Burning
Crusade. That is a per-locale string and not an id, so nothing here reads it.

### On Mists the riding skill sets the speed, not the mount, measured 2026-09-06

Alberto asked whether Master Riding on Mists upgrades the mounts you already own or needs new ones.
**It upgrades them**, and `MountCapability` says so outright: each row maps a required riding skill
to the aura that applies the speed.

| Riding skill | Aura spell | Ground | Air |
|---|---|---|---|
| 75 Apprentice | 86457 | +60% | — |
| 150 Journeyman | 86458 | +100% | — |
| 225 Expert | 86459 | +100% | **+150%** |
| 300 Artisan | 86460 | +100% | **+280%** |
| 375 Master | 86461 | +100% | **+310%** |

And the mount's **type** is what says which of those rungs apply to it - `MountTypeXCapability`,
measured on the same build:

| Mount type | Mounts of it | Riding rungs |
|---|---|---|
| 230 ground | 291 | 75, 150 only |
| 248 flying | 208 | 75, 150, 225, 300, 375 |

So there is no such thing as a *310% mount*: a flyer bought at Expert flies at 150% and the same
flyer flies at 310% once Master Riding is learned, with nothing bought again and nothing gated by
being too fast for its owner. And a ground mount stops at Journeyman's 100% however high the skill
goes, because its type has no rung above 150.

So from Cataclysm onward the mount carries no speed of its own and the skill carries all of it.
**Which means the reading in `Mounts.lua` is right for Era and Burning Crusade and wrong for
Mists**, where it should be `skills[762].rank` against the table above. Written down rather than
fixed, because no member of this family is on that build yet - but it is a known wrong answer and
not an unknown one.

It also explains where 150% came from twice over: Expert is 150% flight from Cataclysm on, and the
druid's Flight Form follows the same ladder there while it is a flat 60% on Burning Crusade. Both
of Alberto's numbers were right, for different builds.

**What it cannot see** is a permission whose mount was destroyed - backlog entry 19, named and
deferred the day it was built.

### Mists has the old skill list as well as the new call, measured 2026-09-06

The comment over Family's modern professions reader said *Mists does not have the skill list at
all*. It has it. `GetNumSkillLines` and `GetSkillLineInfo` answered on a live Mists client with
fifteen rows, riding and every weapon among them:

    Riding 225/225   Daggers 290/290   Defense 290/290   Polearms 1/290   Unarmed 290/290

`GetProfessions` answers for **six slots and only six** - two primaries, archaeology, fishing,
cooking, first aid - so a reader that takes it and stops loses everything else. That is what a
Mists paladin showed: five skills recorded, no riding, no weapons. A Mists druid on the same
client kept both, **by accident** - he has no professions at all, the modern call answered
nothing, and the old path ran as the fallback.

**But weapon ranks on that build are not a fact any more.** Cataclysm took weapon skills out of
the game: there is no Skills tab on the character sheet, and the spellbook carries a single
passive naming which weapons a class may hold, with no number anywhere. The API still hands back
`Axes 166/245`; it governs nothing and is shown nowhere. **Riding is the opposite and is kept** -
its number is not shown either, but it is what decides how fast that character flies.

### The mount journal on Mists, measured 2026-09-06

`C_MountJournal` answers there: `GetNumDisplayedMounts` 258, `GetMountIDs` 520 entries. A row from
`GetMountInfoByID` reads

    Brown Horse         458    132261  false  false  0  false  true  1  false  false  6   false
    Striped Nightsaber  10793  132225  false  true   0  false  true  1  false  true   34  false
    Summon Charger      23214  132226  false  true   0  false  true  1  false  true   84  false

The **second** return is the summoning spell, which is the key `MountSpeeds` and `MountFlight` are
already written in - 458, 10793 and 23214 are all in them. Two fields separate an owned mount from
the rest, and counting how many rows carry each on that paladin says what they are: **field 11 is
true for 7** (the account has them) and **field 5 is true for 3** (this character can use them).
The four in between are flyers the account owns and a rank-150 paladin cannot ride, so field 5
already takes the riding skill into account - it is the one that answers per character.

**A druid's wings are not in the journal**, which a druid who knows Swift Flight Form and owns no
flying mount showed straight away. A flight form is a spell, and what the forms carry is aura
**201, enable-flight** - 115 spells on Mists, both forms among them. On that build the rung
supplies the number the form itself does not, so the two together answer where neither could
alone. It counts as something to ride as well as something to fly with: a druid with a form and no
mount can still get about.

The journal is account-wide but filters to the character who opens it: a druid does not see a
paladin's class mounts. (The window's own *Total Mounts 5* matches neither count; what it totals
has not been established.)

### Which skills the client has a picture for, measured 2026-09-06

Asked because the professions overview is to be drawn as icons rather than words. `SkillLine`
carries `SpellIconFileID`, and what it carries is not the same on the three builds.

| | Era 1.15.9 | Mists 5.5.4 |
|---|---|---|
| Primary professions | **3 of 9** have their own; the rest answer 136235 | 10 of 11 have their own |
| Weapon skills | all 18 answer 136235 | all 17 answer 136243 |

So on Era the column is a placeholder for seven professions out of nine - taking it at face value
would draw the same picture for alchemy, tailoring, mining, herbalism, enchanting, fishing and
skinning. **Mists names them all**, and a file id is the same number on every client, so those are
the numbers to try. Blacksmithing (136241), Leatherworking (136247) and Kodo Riding (135997) are
named by Era itself and are the control: they must render there.

    136240 Alchemy    136246 Herbalism   134708 Mining      136249 Tailoring
    136244 Enchanting 136245 Fishing     134366 Skinning    133971 Cooking
    135966 First Aid  132164 Riding      134071 Jewelcrafting
    237171 Inscription 441139 Archaeology

**Chosen from the sheet on a live Era client, 2026-09-06.** Every file id below rendered there,
which answers the question the sheet was built for: an Era client still ships the art Mists names,
so the professions need nothing chosen by hand.

Two more of the sheet's rows are worth keeping for what they proved. **135997 Kodo Riding rendered**
- it is one of the three Era names itself, so the control held and a flat cell really would have
meant a miss. **441139 Archaeology did not** - the only id on the sheet that failed, and the only
one above four hundred thousand, which is later art an Era client has no reason to ship.

    136241 Blacksmithing   136247 Leatherworking  136240 Alchemy      136246 Herbalism
    134708 Mining          136249 Tailoring       136244 Enchanting   136245 Fishing
    134366 Skinning        133971 Cooking         135966 First Aid    132164 Riding
    134071 Jewelcrafting   237171 Inscription     136243 Engineering

Engineering takes 136243 deliberately - the generic - because nothing better exists for it.

The weapon skills are paths rather than ids and were chosen the same way:

    INV_Sword_04 Swords            INV_Sword_27 Two-Handed Swords
    INV_Axe_01 Axes                INV_Axe_09 Two-Handed Axes
    INV_Mace_01 Maces              INV_Hammer_16 Two-Handed Maces
    INV_Weapon_ShortBlade_05 Daggers   INV_Staff_08 Staves
    INV_Spear_06 Polearms          INV_Gauntlets_04 Fist Weapons
    INV_Weapon_Bow_07 Bows         INV_Weapon_Crossbow_01 Crossbows
    INV_Weapon_Rifle_01 Guns       INV_Wand_01 Wands
    INV_ThrowingKnife_02 Thrown    INV_Shield_06 Defense
    Ability_DualWield Dual Wield

**Lockpicking is 134237** (`inv_misc_key_03`) and **Poisons is 136242** (`trade_brewpoison`), both
found by Alberto in the game and read back by id rather than recognised from a picture. Nothing in
Era's manifest has *lockpick* in its name, so a key is the answer there; `trade_brewpoison` is named
for the thing outright and is better than any of the nine candidates that went on the sheet for it.

Both are **skill line category 7**, with the class skills - Poisons is 40 and Lockpicking is 633 -
which is why neither was in the shipped table before and why poisons was filed under whatever word
the client that read it was set to.

**Unarmed is 132298**, `Ability_Rogue_KidneyShot` - a bare hand striking, which is what was asked
for after the gauntleted fist was turned down. Alberto found it in another addon's picker rather
than on the sheet, and it was identified without guessing: reading his ItemRack sets gave three
file ids, and the manifest named them a helmet, some food and this. **Present on all three builds**,
checked in each one's own manifest rather than assumed from the first.

**Engineering has none anywhere**: it answers 136243 on Mists, which is the same generic every
weapon skill answers. So engineering and the eighteen weapon skills have to be *chosen*, and a
chosen icon is exactly what cannot be verified from inside the client - `GetTexture` echoes back
whatever it was handed. They go through `tools/FamilyIconSheet/` and a screenshot, which is what
that tool is for.

### The client's own list of interface files, measured 2026-09-06

`ManifestInterfaceData` is served for Classic Era: `ID, FilePath, FileName`, 2.2 MB, and **6,507
of its rows are icons**. So *does this client have that art* is answerable from a table after all,
and only *what does it look like* needs the sheet and an eye.

That is worth knowing before the next icon is picked by name from memory: `ability_warrior_punishingblow`
is 132350 and is present on Era, so when it was turned down for Unarmed it was turned down for
looking wrong - a gauntleted fist where a bare one was asked for - and not for being missing. The
two failures are indistinguishable inside the client and are not indistinguishable here.

### The newer auction house, read whole (Mists)

Measured on Mists of Pandaria 2026-09-12, through `/family ah replicate`, one call and one answer.

    the throttled message system is ready: true
    it holds 0 replicated row(s) before asking
    it holds 43002 replicated row(s) now, after 1 answer(s)

**Forty-three thousand rows for one call, in a single `REPLICATE_ITEM_LIST_UPDATE`.** The old
house needed 3,605 pages and most of an hour for a house of comparable size; this is the whole of
it at once.

**The list is numbered from nought.** Index 0 answered a row and so did index 1, which is why the
probe asks for both rather than looping from either.

**Eighteen returns a row, by position, and no names anywhere.** Two examples as they arrived:

    0   Ichor of Undeath / 134437 / 1 / 1 / true / 1 / REQ_LEVEL_ABBR / 0 / 0 / 700
        / 0 / nil / nil / nil / nil / 0 / 7972 / true
    1   Swiftthistle / 134184 / 7 / 1 / true / 1 / REQ_LEVEL_ABBR / 0 / 0 / 54439
        / 0 / nil / nil / nil / nil / 0 / 2452 / true

**Which position is which is not written down here from the look of them.** Family works it out
from the client's *other* description of the same auction: `GetOwnedAuctionInfo` answers **named**
fields - `itemKey.itemID`, `quantity`, `buyoutAmount` - and the player's own listings are
somewhere in the replicated list, so a row carrying all three of an auction's values says where
each of them lives. `Auctions:ReplicateMatchOwned` does that and the probe prints the result. A
row has to match on **every** field: the first stack of 101 anything would otherwise be read as
ours and the map taken from it.

Position seven is the string `REQ_LEVEL_ABBR` - a global's *name*, not its text, which is worth
noticing before anything shows that column to anybody.

Nothing is built on this yet. What is still wanted is the match line from a client where the
player has listings, and whether `GetReplicateItemLink` is there beside the rest (the probe now
reports it).

#### Which position is which

Read on Mists 2026-09-12, from the client's *other* description of the same auctions. The
player's own listings answer named fields through `GetOwnedAuctionInfo`, and they are in the
replicated list too, so a row carrying all of an auction's values says where each one lives:

    looking for your own auctions in the replicated list:
      owned/scanned 4 / 43300
        itemID         17 = 4232
        quantity       3  = 1
        buyoutAmount   10 = 498

**Position 3 is the quantity, 10 is the price, 17 is the item id.** Not read off the shape of
the numbers - matched against what the named route said about the same auction, and a row has to
match on **every** field or the first stack of anything sharing one number becomes ours.

**What that reading did not settle.** The auction that matched had a quantity of **one**, so the
price for one and the price for the whole lot are the same number and position 10 could be either.
`ReplicateMatchOwned` now looks for both forms and labels which one matched, so a single listing
with a quantity above one settles it in one reading.

#### A row can arrive incomplete

The same call, run again a few minutes later, answered 43,300 rows whose first two looked like
this:

    1   (empty)      2   nil      3   1      4   -1      5   false
    6   1            7   nil      8   0      9   0      10  2175500
    11  0            12-15 nil    16  0      17  82204   18  false

The id and the price are there; the name, the texture and the rest are not. **Position 18 was
`true` in the run where the names arrived and `false` in the run where they did not**, which is
the only thing observed about it - what it is called is not known, and no name for it is written
down here. Whatever it is, a reader that wants a name off these rows cannot assume one is
present, and a reader that only wants an id and a price may not care.

#### The price at position 10 is for the whole lot

Settled on Mists 2026-09-12 by a listing of more than one, which is the only kind that can settle
it:

    owned/stacks/scanned 4 / 3 / 20804
      itemID              17 = 3858
      quantity            3  = 20
      buyoutAmount(stack) 10 = 899860

The named route had already said that auction is **twenty** of item 3858 at **44,993** apiece.
The replicated row carries 20 at position 3 and **899,860** at position 10, and 899,860 is
44,993 x 20. So `GetOwnedAuctionInfo.buyoutAmount` is the price of **one** and replicate position
10 is the price of **the lot**.

**A per-item price from a replicated row is therefore position 10 divided by position 3**, and
anything that reads these rows and files a price by item id has to do that division or it will
file a stack of twenty as though one cost twenty times what it does.

The earlier reading could not have found this: the auction that matched then had a quantity of
one, where both prices are the same number. `ReplicateMatchOwned` now walks on past a match that
settles nothing and stops only on a listing of more than one - and it says how many of the
player's listings are of more than one, so a run that could never have answered says so.

### What the client has already spoken for, by modifier

Read on Classic Era 2026-09-12 through `/family itemclick`, which enumerates the client's own
named modified-click actions rather than testing a list of guesses:

    SELFCAST NONE            FOCUSCAST NONE           AUTOLOOTTOGGLE SHIFT
    MAILAUTOLOOTTOGGLE SHIFT STICKYCAMERA CTRL        CHATLINK SHIFT-BUTTON1
    DRESSUP CTRL-BUTTON1     EXPANDITEM SHIFT-BUTTON2 SPLITSTACK SHIFT
    PICKUPACTION SHIFT       PICKUPITEM SHIFT         COMPAREITEMS SHIFT
    OPENALLBAGS SHIFT        QUESTWATCHTOGGLE SHIFT   TOKENWATCHTOGGLE SHIFT
    SHOWITEMFLYOUT ALT       SHOWMULTICASTFLYOUT ALT
    DOMINOS_IGNORE_STICKY_FRAMES ALT

Three things follow.

**`DRESSUP` is `CTRL-BUTTON1`** - the Dressing Room that opens beside Family's own gesture is the
client, under its own name, exactly as its window says.

**`SHOWITEMFLYOUT` is `ALT`**, so the client does claim that key on equipment slots. It is *not*
the bar of alt-clicked armour Alberto saw on his character sheet, which this file said for a few
minutes and had no business saying: he identified that as **ItemRack**. The list explains which
keys are spoken for; it does not say who acted on any particular press, and reading it as though
it did is the same over-reach as naming a column from the shape of its numbers.

**`DOMINOS_IGNORE_STICKY_FRAMES` is in the list**, which is an addon's own action - so this list
takes registrations, and an addon can put a named action of its own in the game's key bindings
screen for the player to rebind.

There is no free single modifier. SHIFT is spoken for eight times over, CTRL by the Dressing Room
and the sticky camera, ALT by two flyouts and an addon. Nothing in the list uses two modifiers
together, which is why CTRL and ALT works at all and why both of its halves fire something else.

### Where a modified click reaches an addon, and where it does not

Confirmed on Era and Mists 2026-09-12: **bag slots, chat links and the inspect window of another
player** all route through `HandleModifiedItemClick`.

**The player's own character sheet does, on a client where nothing is in the way.** Confirmed on
Mists **and on Burning Crusade** 2026-09-12, on neither of which is ItemRack installed: a CTRL and
ALT click on a worn piece opens the family's copies exactly as a bag slot does. Two machines
differing in everything except that one addon, and agreeing - which is what the Era reading needed
and did not have.

This paragraph said the opposite for an hour, on the strength of the Era reading below, and the
claim was wrong. With the probe armed **on Era**, the same click printed nothing at all and
`modified clicks heard since login` stayed at nought - a counter that rises for every modified
click whether or not anybody is listening - so the crossroads really was never reached **there**.
What was not controlled is that the Era client has ItemRack on it and the Mists one does not, and
the conclusion credited the difference to the client. Burning Crusade without ItemRack then
answered it, so what stops the click on Era is the addon and not the client (L-082).

**And ItemRack cannot be asked to leave the key alone.** Its option for disabling alt-click
governs what the key does to bars it has already built, not whether it takes the key at all - so
there is nothing to switch off and nothing to detect. Where something else has claimed the
combination on a window, Family does not get the click there. Accepted rather than worked around:
four places already work, and the fifth would mean fighting another addon for a key on one
window.

(The `clicked` line of that probe, which was blank on Mists, was written down here as a reading.
It was not. Measured on Classic Era 2026-09-12: **`GetMouseFocus` is nil and `GetMouseFoci` is a
function**, answering a list - so the probe had been asking a name that build does not have, and
its blank was a missing call rather than an empty pointer (L-080). Both probes go through one
lookup now, which tries each. The counter above is unaffected, and it is the counter that carries
the conclusion.)

Asked the working way, the client names what it is looking at:

    GetMouseFocus/Foci   nil / function
    0  ItemRackButton4              CheckButton
    1  UIParent                     Frame

That is the bar of item buttons alt-clicking worn armour builds, named by the client rather than
recognised by anybody: **ItemRack**, a CheckButton parented straight to `UIParent`, which is why
it outlives the character sheet and can be dragged anywhere. Anything wanting that window would have
to hook its slot buttons, which is a different mechanism and has had no reading taken.

#### What the whole read costs on Mists

Measured from play 2026-09-12, the finished read of a live house:

    43130 of 43130 row(s) read, 21265 price(s) taken
    read the whole house: 43130 row(s) in 7 second(s), 21265 price(s) taken, 9739 known here

**Seven seconds for the whole house.** The old house on the same evening took five minutes for
394 pages, and 3,605 pages would be about forty-three minutes - so the two houses are not the
same job done twice, they are different jobs. Nothing is paced towards the server here: the list
is already in the client's hands when the reading starts, and the slicing is only so the client
keeps answering its keyboard.

Prices checked on common goods afterwards and correct, which is the reading that says the division
by quantity is right way round.

