# Midnight — what Family asks of the client, and what Midnight answers

The first step of the `midnight` branch, and the one everything after it is written from: which
of the things Family calls Midnight **lacks**, which it has and **answers differently**, and
which it has and **throws**. Measured in a running Midnight client, never from pages about Retail.
The thesis of `addons/Family/Capabilities.lua` holds here more than anywhere: the client's symbol
surface is not evidence about the game.

This file lives on the branch and lands with it. At 5.0.0 what it found moves into
`DATASOURCES.md` §2 and `Capabilities.lua`, and this file goes.

## 1. What Family touches, counted

Counted by `tools/surface.py` from the sources, the compiler's bytecode listing for globals and
the source for what the listing cannot see. First at `2d9780c`, and again on 2026-09-19 at
`51ca01c` after the generator was found to miss every name read through `_G.` or through a local
alias of a namespace (L-103):

| Surface | 2026-09-18 | 2026-09-19 |
|---|---|---|
| Globals Family reads that Lua does not define | 193 | 278 |
| Members of `C_*` namespaces, `Enum` and `TooltipDataProcessor` | 39 | 56 |
| Upper-case string literals, asked about as events | 136 | 136 |
| Frame templates, with the frame type each is built on | 6 | 6 |

**§3 and §4 come from the first runs, which asked the 2026-09-18 list.** Nothing they say is
wrong, but they are silent about the 85 globals and 17 members added since. That includes the
whole bag and bank API, the addon channel and the quest log's replacement calls.

The names themselves are in `tools/FamilySurface/Surface.lua`, which is generated and is the
list. It is not copied here, so it cannot drift from a second copy. `tools/surface.py --check`
says whether it is still current. It is to be run after every `git merge main`.

## 2. How Midnight is asked

`tools/FamilySurface`, a throwaway addon, run on Midnight and on Mists for comparison. It
records the type of every name (and the value of a number or string), whether every literal
registers as an event, whether every template builds, and the answer or error of 100 read-only
calls at login and 43 more inside five windows: trade skill, auction house, bank, mailbox and
merchant. It also records the function names in every `C_` namespace Family uses, which is where a
replacement for an absent call would be. The first runs used version 1, with 99 calls and no
windows. Its README says how to run it.

## 3. What Midnight answered

Midnight 12.1.0, build 69875, interface 120100, on 2026-09-19: one login, an enUS level-50
rogue in a guild, no window open. The saved variables are not in the tree, because they hold a
character, a realm, a guild's name and notes, and gold. What follows is derived from them by
`tools/surface.py --report`, which also names the files. "Absent" below means absent on Midnight;
§4 says which of those Mists lacks too, where Family already copes.

**Nothing threw.** None of the 99 calls, and every one of the six frame templates builds on the
frame type Family uses. The Anniversary trap, a function that exists and throws, was not seen
here. **What Midnight does instead is take things away**: 71 globals and 2 namespace members
are simply `nil`. Every row below is a name that is not there, grouped by what it takes out.

### Professions: the skill sheet and both old recipe windows are gone

- The skill sheet: `GetNumSkillLines`, `GetSkillLineInfo`, `ExpandSkillHeader`,
  `CollapseSkillHeader`.
- The trade skill window: `GetNumTradeSkills`, `GetTradeSkillInfo`, `GetTradeSkillLine`,
  `GetTradeSkillIcon`, `GetTradeSkillCooldown`, `GetTradeSkillItemLink`,
  `GetTradeSkillRecipeLink`, `GetTradeSkillItemLevelFilter`, `GetTradeSkillItemNameFilter`,
  `ExpandTradeSkillSubClass`, `CollapseTradeSkillSubClass`, `SelectTradeSkill`.
- The craft window: `GetNumCrafts`, `GetCraftInfo`, `GetCraftName`, `GetCraftIcon`,
  `GetCraftCooldown`, `GetCraftItemLink`, `GetCraftRecipeLink`, `GetCraftDisplaySkillLine`,
  `ExpandCraftSkillLine`, `CollapseCraftSkillLine`, `SelectCraft`.
- `C_TradeSkillUI.GetTradeSkillLine` is absent. `C_TradeSkillUI.GetAllRecipeIDs` is present and
  answered a table with no window open; `GetRecipeInfo` and `GetRecipeItemLink` are present.
- `GetProfessions()` answers `7 | 8 | 10 | 9 | 6 | nil`: six returns, five of them numbers.
- Events: `TRADE_SKILL_UPDATE`, `CRAFT_SHOW` and `CRAFT_UPDATE` are refused.
  `TRADE_SKILL_SHOW` and `TRADE_SKILL_LIST_UPDATE` register.
- Used in `Family/Scanners/Professions.lua`, `Family_UI/Professions.lua`, `Family_UI/Slash.lua`.

### Spellbook and spells: the spell and spellbook globals are gone

- `GetSpellInfo`, `GetSpellSubtext`, `GetNumSpellTabs`, `GetSpellTabInfo`,
  `GetSpellBookItemInfo`, `GetSpellBookItemName`. `C_Spell.GetSpellInfo(8690)` answers a table.
- Event `LEARNED_SPELL_IN_TAB` is refused.
- `GetSpellInfo` is the widest-reaching absence here: `Family/Names.lua`,
  `Family/Scanners/Character.lua`, `Family/Scanners/Professions.lua`, `Family_UI/Slash.lua`,
  `Family_UI/Tooltip.lua`. The spellbook calls are in `Character.lua`, `Pets.lua` and `Slash.lua`,
  and `GetSpellSubtext` in `Professions.lua` and `Family_UI/Talents.lua`. The flyout calls,
  `GetFlyoutInfo` and `GetFlyoutSlotInfo`, are present.

### Talents: no trees, no glyphs; specialisations answer

- Trees: `GetNumTalentTabs`, `GetTalentTabInfo`, `GetNumTalents`, `GetNumTalentTiers`,
  `UnitCharacterPoints`, `GetNumTalentGroups`, `GetActiveTalentGroup`.
- Glyphs: `GetNumGlyphSockets`, `GetGlyphSocketInfo`, `C_GlyphInfo`.
- Present and answering: `GetNumSpecGroups` 1, `GetActiveSpecGroup` 1, `GetSpecialization` 1,
  `C_SpecializationInfo.GetSpecialization` 1, `GetSpecializationInfo(1)` beginning
  `259 | "Assassination"`. `GetTalentInfo(1, 1)` is present and answers eleven values beginning
  `22337 | "Master Poisoner"`. Whether that is the shape `Family/Scanners/Talents.lua` reads
  on Mists is for the control to say.
- Used in `Family/Scanners/Talents.lua` and `Family/Capabilities.lua`.

### Quests and reputation: the old logs are gone

- Quest log: `GetNumQuestLogEntries`, `GetQuestLogTitle`, `SelectQuestLogEntry`, `QuestLogFrame`,
  `QuestLog_SetSelection`, `QuestLog_Update`. `GetNumQuestLeaderBoards`,
  `GetQuestLogLeaderBoard`, `GetQuestLink`, `GetQuestObjectiveInfo`, `ExpandQuestHeader`,
  `CollapseQuestHeader` and `QuestMapFrame_OpenToQuestDetails` are present. The quest events
  all register. Used in `Family/Scanners/Quests.lua` and `Family_UI/Quests.lua`.
- Reputation: `GetNumFactions`, `GetFactionInfo`, `ExpandFactionHeader`, `CollapseFactionHeader`.
  `UPDATE_FACTION` registers. Used in `Family/Scanners/Character.lua`.

### Currencies: only the namespace

- `GetCurrencyListSize`, `GetCurrencyListInfo`, `GetCurrencyListLink`, `GetHonorCurrency`,
  `GetArenaCurrency` are absent. `C_CurrencyInfo.GetCurrencyListSize()` answers 49.
- Event `HONOR_CURRENCY_UPDATE` is refused. `CURRENCY_DISPLAY_UPDATE` registers.
- Used in `Family/Scanners/Currencies.lua` and `Family/Capabilities.lua`.

### Auction house: the old house is gone, the new one is present bar one call

- `GetNumAuctionItems`, `GetAuctionItemInfo`, `GetAuctionItemLink`, `GetAuctionItemTimeLeft`,
  `GetOwnerAuctionItems`, `CanSendAuctionQuery` are absent, as is
  `C_AuctionHouse.GetAuctionHouseDepositRate`. Every other `C_AuctionHouse` member Family names
  is present.
- Events `AUCTION_ITEM_LIST_UPDATE`, `AUCTION_OWNED_LIST_UPDATE` and
  `AUCTION_BIDDER_LIST_UPDATE` are refused. `AUCTION_HOUSE_SHOW`, `AUCTION_HOUSE_CLOSED`,
  `OWNED_AUCTIONS_UPDATED`, `REPLICATE_ITEM_LIST_UPDATE`, `COMMODITY_SEARCH_RESULTS_UPDATED`,
  `ITEM_SEARCH_RESULTS_UPDATED` and both `AUCTION_HOUSE_BROWSE_RESULTS_*` register.
- Used in `Family/Scanners/Auctions.lua`, `Family_UI/Auctions.lua`, `Family_UI/Slash.lua`,
  `Family_UI/Tooltip.lua`.

### Pets, merchant, bags, bank and add-on metadata

- Pets: `HasPetSpells`, `GetPetTrainingPoints`, `GetStablePetInfo`. The stable events register.
  `Family/Scanners/Pets.lua`.
- Merchant: `GetMerchantItemInfo` is absent. `GetMerchantNumItems`, `GetMerchantItemLink` and
  `GetMerchantItemCostInfo` are present. `Family/Scanners/Merchant.lua`, `Family_UI/Slash.lua`,
  `Family_UI/Tooltip.lua`.
- Bags and bank: `GetContainerItemID` is absent, and `C_Container.GetContainerItemID(0, 1)`
  answered 6948. `GetNumBankSlots`, `KEYRING_CONTAINER` and `ToggleKeyRing` are absent.
  `PLAYERBANKBAGSLOTS_CHANGED` is refused. `PLAYERBANKSLOTS_CHANGED` and `BANKFRAME_*` register.
  `Family/Scanners/Bank.lua`, `Family_UI/Contents.lua`, `Family_UI/Slash.lua`.
- `GetAddOnMetadata` is absent and `C_AddOns.GetAddOnMetadata` answers. `Family/Core.lua`.

### Answers worth holding against Mists

Present on Midnight, and only a comparison can say whether Family reads them right:

- `GetBuildInfo()` answers six values: `"12.1.0" | "69875" | "Sep 15 2026" | 120100 | "" | " "`.
- An item link from `GetItemInfo(6948)` begins `|cnIQ1:|Hitem:6948:`, a quality tag and not a
  hex colour.
- `GetTalentInfo`, `GetProfessions`, `GetSpecializationInfo`, `GetGuildRosterInfo` (17 values),
  `GetNumGuildMembers` (`16 | 1`) and `GetInboxNumItems` (`0 | 0`), as above.

### Loading an addon without Midnight's interface number: refused, observed 2026-09-19

Alberto: Midnight marks Family Surface as *incompatible* and refuses to load it. Its `.toc`
listed `11509, 20506, 50504` and nothing for Midnight. So on Midnight the out-of-date route
that step 2 of the probe's README relied on does not load the addon, and a probe needs the real
number in its `.toc`. The same holds for Family: until the fourth number is in both `.toc`
files, Midnight does not load Family at all. It does not load it and then fail.

**The interface number is 120100** on 12.1.0, read with `/dump select(4, GetBuildInfo())` on
2026-09-19. With `11509, 20506, 50504, 120100` in its `.toc` the probe loaded and ran. An
earlier report that 120100 was also refused is not a finding: the `.toc` sent back after it
was byte-for-byte the repository's three-number one, so Midnight was never shown 120100 in
that run.

## 4. Against Mists, the control

Mists 5.5.4, build 69585, interface 50504, on 2026-09-19. The character was **level 1 and
not in a guild**, so its guild, profession and equipment answers are empty. `--report`
therefore treats a `nil`, or no answer at all, as the state of the character rather than a
different API.

**What Family has never met on any client: 66 globals and 7 events.** These are the §3
absences less seven that Mists lacks too (`GetAddOnMetadata`, `GetContainerItemID`,
`GetCurrencyListLink`, `GetNumTalentTiers`, `ToggleKeyRing`,
`C_AuctionHouse.GetAuctionHouseDepositRate`, `C_TradeSkillUI.GetTradeSkillLine`). The
events are `TRADE_SKILL_UPDATE`, `CRAFT_SHOW`, `CRAFT_UPDATE`, `AUCTION_ITEM_LIST_UPDATE`,
`AUCTION_OWNED_LIST_UPDATE`, `AUCTION_BIDDER_LIST_UPDATE` and `PLAYERBANKBAGSLOTS_CHANGED`.
`HONOR_CURRENCY_UPDATE` and `LEARNED_SPELL_IN_TAB` are refused on Mists as well. Of these,
the refusals cost nothing, because `Family:RegisterEvent` already answers false for an unknown
event. The absent calls are the work.

**Midnight has things Mists does not**, and they are the other half of the work:
`GetSpecialization`, `GetSpecializationInfo`, `GetActiveSpecGroup`, `GetQuestObjectiveInfo`,
`C_CurrencyInfo.GetCurrencyListSize`, and `C_TradeSkillUI.GetAllRecipeIDs`,
`GetRecipeInfo` and `GetRecipeItemLink`, which is to say a recipe list that can be read.

**Mists throws, Midnight does not.** `GetNumTalentGroups`, `GetNumTalentTabs` and
`GetNumTalents(1)` exist on Mists and throw *API unsupported in this version of World of
Warcraft*, which is the Anniversary trap again. On Midnight the same three are simply absent.

**Answered in a different shape**, of the calls both clients made:

- `GetBuildInfo()`: six values on Midnight, seven on Mists. Family reads only the fourth
  (`Capabilities.lua:70`, `Scanners/Auctions.lua:687`, `Family_UI/Slash.lua:2470`), and both
  return it, so this costs nothing.
- `GetTalentInfo(1, 1)`: Mists puts the name first (`"Void Tendrils" | 537022 | …`) and
  Midnight puts a number first and the name second (`22337 | "Master Poisoner" | 132108 | …`).
  `Scanners/Talents.lua` tries several readers, `C_SpecializationInfo.GetTalentInfo` first,
  and takes the name as the first string wherever it falls. So this may already be handled.
  **But the probe never called `C_SpecializationInfo.GetTalentInfo`**, the reader Family
  prefers and Midnight has. That is the gap.
- Item links: Mists colours a link `|cffffffff|Hitem:6948:…` and Midnight writes a quality tag,
  `|cnIQ1:|Hitem:6948:…`. The four places Family reads a link (`Core.lua:160`,
  `Scanners/Auctions.lua:2566`, `Scanners/Character.lua:71`, `Family_UI/Slash.lua:502`) all
  match `|H(item[%-%d:]+)|h`, and run under `lua5.1` against both clients' links it returned
  the item string, and with `%[(.-)%]` and `item:(%d+)` the name and id, from all three
  links tried. The one colour pattern in the tree, `|c%x%x%x%x%x%x%x%x` in `Core.lua:621`,
  would not strip `|cnIQ1:`. It cleans Chronoboon Displacer tooltip rows, a Classic item.
- `GetGuildRosterInfo(1)`: position 10 was `0` on Midnight and `""` on Mists. **Settled on
  2026-09-19: the same shape.** Against a guilded Mists character (Eccebombo, a level-49 guild
  master, probe version 2) the row reads `"Eccebombo-MirageRaceway" | "Guild Master" | 0 | 49 |
  … | 0 | "PALADIN" | …`, with `0` at position 10 as on Midnight. The `""` was a character
  outside a guild.
- `GetProfessions()`: the same shape, six values on both: `7 | 8 | 10 | 9 | 6 | nil` on
  Midnight, `7 | 9 | nil | 8 | 6 | 5` on Eccebombo.
- `GetInventoryItemID("player", 1)`: one value on Midnight, two on Mists (`10763 | 0`). All
  five call sites keep only the first (`Scanners/Bags.lua:253`, `Scanners/Bank.lua:142`,
  `Scanners/Character.lua:48`, `Family_UI/Slash.lua:272` and `:915`), so this costs nothing.
- `GetTalentInfo(1, 1)` on Eccebombo has the same layout as on Holycuw, name first
  (`"Speed of Light" | 571558 | …`), so the difference from Midnight is the client's, not the
  character's.

## 5. Inside the windows, and what the namespaces hold (probe version 2)

Midnight: Ahia, 12.1.0, all five windows opened, 2026-09-19. Mists: Eccebombo (a level-49
guild master with professions; auction house, bank, mailbox, trade skill) and Duecalzini
(mailbox, trade skill), both on Mirage Raceway. Read with
`tools/surface.py --report <Midnight>@Ahia <Mists>@Eccebombo`.

**The longer list adds 7 absences** to §4's 66, for 73 globals missing on Midnight and present
on Mists: `BANK_CONTAINER`, `NUM_BANKBAGSLOTS`, `UnitBuff` (`Core.lua`), `GetRaceAtlas`
(`Races.lua`), `LOOTFRAME_NUMBUTTONS` (`Family_UI/Tooltip.lua`), and `QueryAuctionItems` and
`PlaceAuctionBid`, which `Scanners/Auctions.lua` hooks. No namespace member is missing on
Midnight and present on Mists. Nothing threw on Midnight, and no call answered in a new shape
inside a window.

**The talent reader Family asks first answers the same on both.**
`C_SpecializationInfo.GetTalentInfo{tier = 1, column = 1, groupIndex = 1, isInspect = false}`
returns an 18-field table carrying `name` on Midnight (`"Master Poisoner"`) and on Mists
(`"Speed of Light"`). So the different layout of the global `GetTalentInfo` in §4 probably
does not matter: `Scanners/Talents.lua` tries this reader first. Whether it is the one chosen
there is a question for the code, not the client.

**The bank: Family's containers are empty on Midnight.** With the bank open:

| | Midnight | Mists |
|---|---|---|
| `C_Container.GetContainerNumSlots(-1)` | 0 | 28 |
| `C_Container.GetContainerNumSlots(5)`, Family's first bank bag | 0 | 14 |
| `C_Container.GetContainerItemInfo(-1, 1)` | nothing | a table, `itemID=11965` |
| `GetNumBankSlots()` | absent | `3 \| false` |

`BANK_CONTAINER` and `NUM_BANKBAGSLOTS` are absent, so `Scanners/Bank.lua` falls back to -1 and
bag 5 and reads nothing. The bank's contents are in containers Family does not ask, and which
ones is **not yet observed**.

**The trade skill: the new list reads.** `C_TradeSkillUI.GetAllRecipeIDs()` returned 454 ids.
`GetRecipeInfo` on the first returned a 28-field table carrying `hyperlink`, and
`GetRecipeItemLink` returned an item link. `GetProfessions()` is unchanged. On Mists the same
window answered through the old calls (`GetNumTradeSkills()` 56, `GetTradeSkillLine()`
`"Cooking" | 250 | 300`). What Midnight has in place of `GetTradeSkillLine` is among the 141
`C_TradeSkillUI` functions Mists lacks, which include `GetBaseProfessionInfo`,
`GetProfessionInfoBySkillLineID`, `GetChildProfessionInfos` and `GetTradeSkillLineForRecipe`.
Those names were read off the client, and none has been called.

**The auction house: the new API reads what Family needs.**
`C_AuctionHouse.GetNumOwnedAuctions()` answered 1, and `GetOwnedAuctionInfo(1)` a table carrying
`auctionID`, `buyoutAmount`, `quantity`, `status`, `timeLeftSeconds` and `itemKey`. Browse
results and the replicate list were empty, as expected with no search and no full scan.

**The mailbox: unchanged.** `GetInboxNumItems`, `GetInboxHeaderInfo`, `GetInboxItem` and
`GetInboxItemLink` all answered with a letter from the auction house.

**The merchant: one call gone and no replacement seen.** `GetMerchantNumItems` (40),
`GetMerchantItemLink` and `GetMerchantItemCostInfo` answer. `GetMerchantItemInfo` is absent, and
no namespace Family uses holds a replacement. The merchant window was not opened on Mists, so
there is no control for it.

**What the namespaces hold on Midnight and not on Mists**, by count: `C_TradeSkillUI` 141,
`C_QuestLog` 80, `C_Item` 39, `C_CurrencyInfo` 34, `C_Spell` 18, `C_Container` 17,
`C_SpecializationInfo` 17, `C_Map` 16, `C_ChatInfo` 13, `C_MountJournal` 6, `C_GuildInfo` 1. The
report prints the names. This is where the code step will look for replacements, and each one
chosen will be called in a client before it is relied on.

## 6. The bank and the merchant (probe version 3)

Midnight, Ahia, 12.1.0, 2026-09-19, with the bank and a vendor opened, and with Bagnon, which
replaces the bag and bank frames, enabled. A second character with Bagnon disabled is the next
run.

**Where the bank is: containers 6 to 12.** The sweep of ids -20 to 40:

| When | Containers with slots |
|---|---|
| at login | 0 = 20, and 1, 2, 3, 4 = 30 each |
| with the bank open | the same, and **6, 7, 8, 9, 10, 11, 12 = 98 each** |

Items were found in 6, 9, 10 and 12. Family reads the bank as -1 and 5 (§5), and both answer 0,
so it reads none of the seven. **Not yet observed:** whether any of the seven belong to the
account rather than the character. That needs the bank opened on a second character, to see
whether a container's first item repeats.

**A second character, with Bagnon disabled** (Mara, probe version 4, 10:56). The same seven
containers, 6 to 12, with 98 slots each, so Bagnon was not changing what the first run saw. The
first item in each container, against Ahia's:

| Container | Ahia | Mara |
|---|---|---|
| 6 | 114821 | 114821 |
| 7, 8, 11 | empty | empty |
| 9 | 7191 | 10940 |
| 10 | 71325 | 18466 |
| 12 | 122637 | 122637 |

Alberto, from the game: the bank has six tabs, four of them bags and the last two void storage,
and the warband bank has one tab, with more for sale. Six and one make the seven containers.
Container 12 has the same first item on both characters, which fits it being the warband tab.
**Not settled:** container 6 matches too, and a first item cannot tell a shared container from
the same item kept in the same place. Nor does the sweep say which two are void storage.

**Container 5 is a carried bag on Midnight.** Mara's login sweep, before any bank, has 5 = 26
slots (Ahia has no container 5). `NUM_BAG_SLOTS` is absent on Midnight (§5), so Family's bag
scanner would read 0 to 4 and miss it, and `Scanners/Bank.lua` would take 5 as the first bank
bag.

**What replaces `GetMerchantItemInfo`: `C_MerchantFrame.GetItemInfo(index)`.** At a vendor it
answered a table for item 1: `name` "Tough Hunk of Bread", `price` 20, `stackCount` 5,
`numAvailable` -1, `isPurchasable`, `isUsable`, `hasExtendedCost` false, `texture` 133964.
`C_MerchantFrame` holds seven functions. The five other `Get…` and `Is…` ones answered, and
`SellAllJunkItems` was listed and not called.

**Mists, the control (Duecalzini, version 3, 2026-09-19): no answer to compare.** Two seconds
after the vendor opened, `GetMerchantNumItems()` answered 0 and every item call answered
nothing. **The vendor did sell goods** (Alberto, 2026-09-19): an innkeeper, reached through its
dialog by choosing the option that opens the goods. The probe answered, so `MERCHANT_SHOW` fired,
and the list was either not there yet or the window had already closed when the probe asked. Version 4 of the probe asks the
merchant the moment it opens and again two seconds later, and records each time whether
`MerchantFrame` is still shown, which is a second name taken from memory. What it does show:
`GetMerchantItemInfo` exists on Mists, and `C_MerchantFrame` exists there with one function,
`GetBuybackItemID`, so `C_MerchantFrame.GetItemInfo` is Midnight's and not Mists'.

The same run's login sweep, for the record: -2 = 32, -1 = 28, 0 = 20 and 1 to 4 = 12. A keyring
container of 32 slots answers on Mists, where `Capabilities.lua` has the keyring confirmed absent
in the game since 2026-08-08. That is one more case of the client's surface disagreeing with the
game, and it changes nothing here.

**Mists, the control again (Duecalzini, version 4, 2026-09-19): a plain vendor answers.**
It had 8 items, `GetMerchantNumItems()` answered 8 both the moment the window opened and two
seconds later, and item 1 was *Bold Tourmaline*. `MerchantFrame:IsShown()` was `false` the first
time and `true` the second, so the list is there before the frame is drawn. **Why the
innkeeper's goods answered nothing is not isolated**: that run did not record `IsShown`, so a
window already closed and the dialog path cannot be told apart. Family reads a vendor on
`MERCHANT_SHOW`, so an innkeeper's goods are worth one look when the merchant scanner is
written.

**The old call and its replacement carry the same eight facts.** Mists'
`GetMerchantItemInfo(1)` answers `"Bold Tourmaline" | 134130 | 18000 | 1 | -1 | true | true |
false | nil`, which is name, texture, price, quantity, available, purchasable, usable and extended
cost. Midnight's `C_MerchantFrame.GetItemInfo(1)` answers a table with `name`, `texture`,
`price`, `stackCount`, `numAvailable`, `isPurchasable`, `isUsable` and `hasExtendedCost`. That is
a list turned into a table, observed on both sides, though on different items.
`GetMerchantItemLink` and `GetMerchantItemCostInfo` have the same shape on both clients.

**On Midnight the item's name arrives after the table.** Mara, same vendor: the moment the
window opened, `C_MerchantFrame.GetItemInfo(1)` answered 8 fields with **no `name`**. Two seconds
later it answered 9, `name` "Tough Hunk of Bread" among them. `GetMerchantNumItems()` was 40 both
times, and `MerchantFrame:IsShown()` was `false` then `true`. On Mists `GetMerchantItemInfo`
carried the name at once. A merchant reader on Midnight cannot count on the name when the
window opens.

**Professions: journals.** Alberto: Midnight has profession journals too. Not observed by the
probe; recorded as reported.

### Still to do for step 1

1. ~~Where the bank is on Midnight~~: containers 6 to 12 (§6). Which of them is the warband
   tab and which two are void storage are not settled by the sweep.
2. ~~What replaces `GetMerchantItemInfo`~~: `C_MerchantFrame.GetItemInfo` (§6).
3. ~~A Mists vendor, as the control for the merchant calls~~: obtained with version 4 (above).
   An innkeeper's goods, reached through its dialog, answered nothing once, and why is not
   isolated. Of the merchant calls Midnight still has, `GetMerchantItemLink`
   answered an ordinary link and `GetMerchantItemCostInfo` 0 for a vendor's bread. What a
   Mists vendor with goods would add is the shape of those two on the client where Family
   already works.
