# Midnight — what Family asks of the client, and what Midnight answers

The first step of the `midnight` branch, and the one everything after it is written from: which
of the things Family calls Midnight **lacks**, which it has and **answers differently**, and
which it has and **throws**. Measured in a running Midnight client, never from pages about Retail.
The thesis of `addons/Family/Capabilities.lua` holds here more than anywhere: the client's symbol
surface is not evidence about the game.

**Every Midnight observation here comes from an account that has not bought the Midnight
expansion** (§7): the 12.1.0 client, on an account without the expansion. Anything the purchase
unlocks may be absent from all of it.

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

Alberto's screenshot of Mara's bank, 2026-09-19: *Tab 1* is a grid of 14 by 7, **98 slots**, the
count the sweep gives each of 6 to 12. The window shows six character tab buttons, and *Warband
Bank* as a separate tab along the bottom. The first slot of Tab 1, and the whole first column,
hold an item with the same icon as the *Hexweave Bag*s of the bag screenshot. So container 6's
first item, 114821 on both characters, is likely a spare bag kept in the same slot by both, and
not a shared container. That rests on an icon: the id's name was not read.

**The containers are the tabs, in order.** Alberto's screenshots of Mara's tabs, against Mara's
sweep:

| Tab, as the game shows it | Screenshot | Container, sweep |
|---|---|---|
| 1 | items, first slot filled | 6: first item at slot 1 |
| 2 | empty | 7: empty |
| 3 | empty | 8: empty |
| 4, named *Reagents* | items, first slot filled, stacks up to 1000 | 9: first item at slot 1 |
| 5, named *Void Storage 1* | items, first slot filled | 10: first item at slot 1 |
| 6 | empty | 11: empty |
| Warband Bank, *Tab 1*, its only tab | items, first slot filled, 14 by 7, with a `+` to buy more | 12: first item at slot 1 |

**All seven fit, in tab order**, and the last two were predicted from the sweep before they were
seen. **Container 12 is the warband tab**, and it is the one whose first item, 122637, was the
same on Ahia and on Mara, as a tab shared by the account should be. Containers 6 to 11 are the
character's six bank tabs. On Mara the fifth is named *Void Storage 1* and the fourth *Reagents*,
which is what Alberto meant by bags and void storage.

**Container 5 is a carried bag on Midnight: the reagent bag.** Mara's login sweep, before any
bank, has 5 = 26 slots (Ahia has no container 5). Alberto's screenshot of Mara's bags, 2026-09-19,
shows it as a *Gatherer's Reagent Bag*: a first row of 2 slots and six rows of 4, 26 in all,
beside four *Hexweave Bag*s, which are containers 1 to 4 at 30 each. `NUM_BAG_SLOTS` is absent on Midnight (§5), so Family's bag
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

## 7. What the game shows, from Alberto's screenshots, 2026-09-19

Seen in the Midnight client, on a level-70 warrior (Mara's bags and bank are §6). These are
screenshots, not calls, and are recorded as what the game displays.

**The account has not bought Midnight.** The *Housing Dashboard* says *Please purchase Midnight
to access Housing*. Its catalogue still opens (a *BlizzCon Doormat*, *Vendor: World Vendors*,
*Cost: 500* gold), as does *Blueprints 0/50*. Housing is a domain Family has no part in.

**A profession has one skill line per expansion, and Family keeps one rank per profession.** The
*Professions* window lists *Enchanting*, *Dragon Isles Enchanting 1/100*; *Skinning*, *Khaz Algar
Skinning 8/100*; *Cooking*, *Dragon Isles Cooking 1/100*; *Fishing*, *Dragon Isles Fishing 1/100*;
and *Archaeology*, *Draenor Master 235/700*. Each is one expansion's line, with its own cap.

**Journals are a gathering profession's window.** *Skinning Journal* and *Fishing Journal* sit
beside the profession's own spell. The skinning journal, titled *Khaz Algar Skinning*, has a
*Journal* tab (*Skinning Details*, and under *Unlearned* the *Refinement* and *Bait Recipes*,
with gathering details such as *Primary Reagent Difficulty*, *Skill*, *Finesse*, *Deftness* and
*Perception*) and a *Specializations* tab (*Tanning*, *Harvesting*, *Luring*, all locked). The
fishing journal lists fish under *General Fishing*, *Freshwater*, *Saltwater* and *Specialty
Fishing*. A toast in the bag screenshot reads *You can now choose a new Skinning Specialization
to unlock*. Profession specialisations exist on Midnight, and are not the Classic ones Family
records.

**Specialisation, talents, spellbook.** The *Specialization* tab shows *Arms* and *Fury*
(*Damage*) and *Protection* (*Tank*), Fury *Active* and the other two with *Activate*. *Talents*
shows two node trees, *Warrior 23* and *Fury 23*, *Hero Talents*, unlocked at level 71, three
*PvP* talent slots and a *Default Loadout*. That is not the tier-and-column grid that
`Scanners/Talents.lua` reads. The *Spellbook* has a *Warrior* tab laid out by specialisation, the
inactive ones greyed out, and a *General* tab.

**Against the features in `Capabilities.lua`**, where a screenshot shows the thing. Everything
else is not seen:

| Feature | What the game shows | Reading |
|---|---|---|
| `weaponSkills` | *Weapon Skills*, *Passive*, in the spellbook's General tab, with no number | no, as on Mists |
| `flying` | *Skyriding*, *Skyriding Flight Style* and *Master Riding* in the General tab | yes, for this character |
| `dualSpec` | three specialisations, one active, the others with *Activate* | more than one, of a kind the column's name does not describe |
| `talentTrees` | two node trees, hero talents and loadouts | trees, but not the Classic kind the column means |
| `glyphs`, `keyring`, `ammoBags`, `guildBank`, `achievements`, `currencies`, `dailyQuests`, `transmogrify` | not in these screenshots | not seen |

The sweep adds that no keyring container answers on Midnight (§6), which is API evidence, not
the game's.

## 8. A brief on Midnight's professions, from wow-professions.com, read 2026-09-19

**Hypotheses, not evidence.** Alberto asked for the site's Midnight section to be read as
foreknowledge to steer the probes. Nothing here enters `Capabilities.lua`, a harness stub or
Family's data until a client has shown it. The pages read: the hub `/midnight`, each crafting
profession's `/midnight/<profession>-guide` and `-specialization-guide-and-builds`, the herbalism
and mining specialisation pages, `/midnight/profession-knowledge-treasure-locations`, and the
alchemy, skinning, fishing and cooking leveling guides under `/guides/`. They agree with one
another on everything below. Where they differ or are silent, that is said.

**The account in hand cannot see most of it.** The pages describe the *Midnight* tier
(*Midnight Alchemy 1-100*, trainers in Silvermoon City), and this account has not bought
Midnight (§7). Its characters show *Dragon Isles* and *Khaz Algar* lines only. The probes can
test the machinery on those tiers and cannot test the Midnight tier.

### What the pages claim

- **One skill line per expansion.** *Midnight Alchemy*, *Midnight Skinning* and so on, each
  from its own trainer, each **1-100**, except **Fishing, whose cap is 300**, "same as The War
  Within". No page says how the lines relate to one another. That agrees with the
  *Professions* window in §7, which showed *Dragon Isles* and *Khaz Algar* lines at /100.
- **Specialisations spent with knowledge points.** Four trees per crafting profession, unlocking
  at skill **25, 50, 60 and 75** (stated for alchemy, inscription, jewelcrafting and
  leatherworking). Gathering professions have two or three trees. Nodes are capped (30 points
  on inscription, 20 to 30 on enchanting). Respec is **not covered** on any page. Names per
  profession: Alchemy (*Potion Prowess*, *Fluent in Flasks*, *Transmutation Authority*,
  *Alchemical Mastery*), Blacksmithing (*Craftsmithing*, *The Old Ways*, *Armorsmithing*,
  *Weaponsmithing*), Enchanting (*Elevating Equipment*, *Transitories, Tonics, and Tools*,
  *Disenchanting Delegate*, *Spellbound Shatterer*), Engineering (*Market Mobility*, *Combat
  Analytics*, *Recycling*, *Bits and Bots*), Inscription (*Blueprints*, *Calm Hands*, *Perfected
  Products*, *Darkmoon Curiosity*), Jewelcrafting (*Thoughtful Throughput*, *Glamorous Gems*,
  *Alluring Accessories*, *Proficient Processor*), Leatherworking (*Learned Leatherworker*,
  *Lasting Leather*, *Safeguarding Scales*, *Flawless Fortes*), Tailoring (*Sin'dorei Finery*,
  *Nimble Needlework*, *Fabric Specialist*, *Fiber Arts*), Mining (*Meticulous Mining*,
  *Plentiful Ores*), Herbalism (*Bountiful Harvests*, *Botany*), Skinning (*Thorough Tanning*,
  *Gainful Gathering*, *Talented Tracker*). The Khaz Algar skinning trees in §7's screenshot are
  *Tanning*, *Harvesting* and *Luring*, so the names change by tier.
- **Knowledge points come from many sources.** Every profession has **8 treasures at 3 each**
  (24), which the treasures page says are **character-specific** and **tracked by quest flags**
  (it gives `C_QuestLog.IsQuestFlaggedCompleted` with quest 89117 for one). Every profession
  also has a renown book (10), a weekly trainer quest (1 to 3), weekly drops (4 for crafters,
  about 8 or 9 for gatherers), an Inscription treatise (1) and the Darkmoon Faire (3 a month,
  and +2 skill). Crafters get patron crafting orders (about 12 a week); enchanters get
  disenchanting drops instead (about 9); gatherers get 1 per first gather of a node type (25 for
  mining, 34 for herbalism). "Flicker" items stand in for "Glimmer" ones as a catch-up. The
  totals claimed are 40 to 70 on the first day and about 17 to 20 a week.
- **Quality.** Reagents and consumables have **two** qualities, *Silver* and *Gold*, where The War
  Within had three. Weapons, armour and profession equipment keep **5 ranks**. Concentration
  "guarantees Gold". Its size, regeneration and cost are **not covered**.
- **Profession stats and equipment.** *Resourcefulness*, *Multicraft*, *Ingenuity* and crafting
  speed for crafters; *Finesse*, *Deftness* and *Perception* for gatherers. Each profession has
  **three equipment slots**, a tool and two accessories (Cooking has two), in green, rare and a
  new **epic** quality.
- **A currency per profession.** *Artisan <Profession>'s Moxie*, bind-on-pickup, replacing The War
  Within's shared *Artisan's Acuity*.
- **Cooldowns.** Alchemy's transmutes share an **18-hour** cooldown, and its *Wondrous Synergist*
  is daily (about 9 hours with the right nodes). Tailoring has "daily bolt cooldowns". The
  other pages say nothing.
- **Changes from The War Within** that touch what Family records: Bronze quality gone,
  refining of skins gone, the engineering Invent cycle replaced by Recycling, Darkmoon cards
  crafted again, fishing lures moved out of skinning, and new enchant slots (helm, shoulder)
  with cloak and bracer enchants removed.

### What the client already offers to test it

These are all names Midnight reported in the namespace listings (probe version 2, §5), not taken
from the site:

- Per-expansion lines: `C_TradeSkillUI.GetAllProfessionTradeSkillLines`,
  `GetProfessionInfoBySkillLineID`, `GetChildProfessionInfos`, `GetChildProfessionInfo`,
  `GetBaseProfessionInfo`, `GetProfessionChildSkillLineID`, `GetTradeSkillLineForRecipe`.
- Concentration: `C_TradeSkillUI.GetConcentrationCurrencyID`.
- Profession equipment: `C_TradeSkillUI.GetProfessionSlots`, `GetProfessionInventorySlots`.
- Cooldowns and first crafts: `C_TradeSkillUI.GetRecipeCooldown`, `IsRecipeFirstCraft`.
- Quality: `C_TradeSkillUI.GetItemCraftedQualityInfo`, `GetItemReagentQualityInfo`,
  `GetQualitiesForRecipe`.
- Treasures and weeklies: `C_QuestLog.IsQuestFlaggedCompleted` and
  `IsQuestFlaggedCompletedOnAccount`.
- **Not in any namespace Family uses: the specialisations and their knowledge points.** Finding
  where they live means naming a namespace, as `C_MerchantFrame` was named.

## 9. Mists checked for the same gap: none in professions

Alberto, on a Mists character, 2026-09-19: professions there still work the old way. There is one
profession with one skill value, capped at **600**, and each expansion adds or changes recipes
within it. So Family's one-rank-per-profession model is right on Mists, and the gap in §7 is
Midnight's alone.

The one exception is cooking's six *Way of* lines, which Family set aside on purpose (backlog 24,
*SET ASIDE 2026-09-06*). Backlog 24 measured them as **child skill lines**, `SkillLine` 975 to
980 with `ParentSkillLineID` 185, cooking. Midnight's per-expansion lines may be the same kind of
thing: the client offers `C_TradeSkillUI.GetChildProfessionInfos` and
`GetProfessionChildSkillLineID` (§8). **A hypothesis**, not yet asked of either client, but if it
holds, one model of parent and child skill lines would serve both the Way of lines on Mists and
Midnight's tiers.

## 10. A brief on Housing, from housing.wowdb.com, read 2026-09-19

**Hypotheses, not evidence**, under the same decision as §8. Pages read: the front page,
`/progression/`, `/tools/decor-sync/`, `/neighborhoods/alliance/`, `/endeavors/`, `/vendors/` and
`/decor/`. Most of the site is a database of decor items, and it was not read item by item.

Housing is a domain Family has no part in. Whether Family should record any of it is a question
for the specification, and so Alberto's. This brief exists so the probe can find out what the
client offers.

- **Decor collections are account-wide.** The sync tool's page: "Since decor collections are
  account-wide in WoW, you only need to sync from one character." Family records characters,
  so this would be a first account-wide record.
- **An addon can read the collection.** The site syncs through an addon, *Dump Decor*, which writes
  "owned decor items from your collection" and "currently placed decor in your house" to an
  export string or a SavedVariables file. That shows the client exposes both lists to an addon.
  The page names no API.
- **House level: 12 levels** by cumulative XP, earned by "Unlock decor". Each level raises the
  placement budget (interior 910 at level 1, 5,975 at level 12; exterior 200 at level 1) and
  unlocks rooms and exteriors. The page says its numbers are from the test realm.
- **Decor: 3,158 items**, each with a category (*Accents*, *Functional*, *Furnishings*, *Lighting*,
  *Miscellaneous*, *Nature*, *Structural*), a budget cost, a size, whether it is dyeable, and
  whether it goes indoors, outdoors or both. They are sold for gold and more than 20 other
  currencies across every expansion's vendors, crafted, or earned.
- **Neighbourhoods by faction**: *Founder's Point* (Alliance) and *Razorwind Shores* (Horde),
  with plots of differing terrain. How a plot is obtained, and whether a house belongs to the
  account or the character, is **not covered**.
- **Endeavors**: neighbourhood tasks, 10 listed with 20 to 34 tasks each. Cadence and rewards
  are **not covered**.

On this account, which has not bought Midnight, the *Housing Dashboard* opens its catalogue and
*Blueprints 0/50* but says *Please purchase Midnight to access Housing* (§7). How much of this a
probe can reach here is itself a question for the probe.

## 11. A brief on the Catalyst and Apex talents, read 2026-09-19

**Hypotheses, not evidence**, under the decision of §8. Pages: Icy Veins, `/wow/catalyst-guide`,
and Wowhead, `/guide/midnight/apex-talents-overview` (read with the web-read tool, whose text was
taken from the page's own markup; the per-specialisation lists were skimmed, and the mechanics
at the top read in full).

- **Apex talents** are nodes added to the bottom of every specialisation's tree, with four
  points over three talents in sequence, the middle one taking two. They are optional. They
  unlock at levels **81, 84 and 90**, and only after **20 points** in the specialisation tree.
  **The level cap rises to 90.** Midnight's `GetMaxPlayerLevel()` answered 90 in the first run
  (§3), on this account without the expansion. That agrees, and is the client's answer, not
  the game's.
- **A new Demon Hunter specialisation, *Devourer***, is listed beside Havoc and Vengeance.
  Family records the active specialisation and the build of both (specification §3). A class
  with more than three is a question for the probe:
  `C_SpecializationInfo.GetNumSpecializationsForClassID` is in Midnight's own list.
- **The Catalyst** turns seasonal non-set gear into class set pieces (head, shoulder, chest,
  hands and legs count towards set bonuses). Its **charges are a character currency**,
  *Crystallized Venomblight Manafluxes*: one at season start, one every two weeks, one from an
  achievement, **capped at 8** on a character, and not account-wide. Since 12.1, catalysed pieces
  keep their secondary stats. Family records currencies (specification §3). Whether this one is
  in the currency list is for the probe.

## 12. What version 6 answered, and what it cost on Mists (2026-09-19)

Midnight 12.1.0, build 69875: **Ahia**, all five windows opened, read with
`tools/surface.py --report <file>@Ahia`. The file also holds two older runs, Druiduga and Mara,
which predate version 6 - a run's key is the client version and the character, so earlier runs
sit beside the new one rather than being replaced. Only Ahia's carries a `census`.

**There is no Mists control for any of this.** Version 6 crashed that client (below), so the
comparisons in §4 and §5 are still the newest ones taken, and they were taken with the earlier
list. Everything here is a raw Midnight reading: an absence below is absent on Midnight, and
whether Mists has it is not re-asked.

The counts: **99 globals absent, 2 namespace members absent, 74 literals refused as events, 0
templates that fail to build, 1035 calls answered, 243 that throw.** The two members are
`C_AuctionHouse.GetAuctionHouseDepositRate` and `C_TradeSkillUI.GetTradeSkillLine`. **All 243
throws are from the no-argument sweep** - 219 in `discovery`, 24 in `tradeSkill`, every one of
them *bad argument #1 … Usage:*, which is a function saying what it wants. Nothing Family calls
threw, which is what §3 said of the first run and still holds.

### Professions: the per-expansion lines are real, and they are parent and child

`C_TradeSkillUI.GetAllProfessionTradeSkillLines()` answers **157** skill lines, and
`GetProfessionInfoBySkillLineID` describes each one with an `expansionName` and a
`parentProfessionID`/`parentProfessionName`. Twelve expansions of eleven professions each -
Classic, Outland, Northrend, Cataclysm, Pandaria, Draenor, Legion, Kul Tiran, Shadowlands,
Dragon Isles, Khaz Algar, **Midnight** - and 25 more named *Unknown*. So 2500 is *Legion
Engineering*, parent 202 *Engineering*.

**This settles the hypothesis at the foot of §9**: Midnight's tiers are child skill lines under a
parent, which is the shape backlog 24 measured for cooking's six *Way of* lines on Mists
(`SkillLine` 975 to 980, `ParentSkillLineID` 185). One model of parent and child would serve both.

**And it is only readable with the window open.** At login `GetBaseProfessionInfo()` answers a
zeroed table and `GetChildProfessionInfos()` an empty one. With Ahia's engineering window open:

| Call | Answer |
|---|---|
| `GetBaseProfessionInfo()` | *Engineering*, `professionID` 202, `skillLevel` 305, `maxSkillLevel` 805 |
| `GetChildProfessionInfo()` | *Kul Tiran Engineering*, `professionID` 2499, `parentProfessionID` 202, `skillLevel` 55, `maxSkillLevel` 180 |
| `GetChildProfessionInfos()` | 8 tables |
| `GetProfessionChildSkillLineID()` | 2499 |
| `GetProfessionInventorySlots()` | 11 slots, inventory ids 19 to 29 |

That is the §7 gap measured: one profession is a parent with a skill of its own and a child line
per expansion, each with its own skill and cap. Family's one-rank-per-profession model reads the
parent and is silent about eight children.

### Concentration: 24 of the 157 lines have a currency

Three tiers, eight crafting professions each - the three gathering lines have none, and every
older tier answers 0:

| Tier | Currency ids |
|---|---|
| Dragon Isles | 3047 to 3054 |
| Khaz Algar | 3013, 3040 to 3046 |
| **Midnight** | 3161 to 3168 |

**Read on an account that has not bought Midnight**, so the skill-line table and its currencies
are client data rather than something the purchase unlocks. What they are *called* is not here;
see the limitation below.

### `C_ProfSpecs` is where the specialisations live

§8 ended by saying the specialisations and their knowledge points are in no namespace Family
uses, and that finding them would mean naming one from memory as `C_MerchantFrame` was named.
It did not come to that: the sweep's own words include `Prof`, and the census found
**`C_ProfSpecs`** (27 functions) - `GetConfigIDForSkillLine`, `GetCurrencyInfoForSkillLine`,
`GetSpecTabIDsForSkillLine`, `GetPerksForPath`, `GetStateForPath`. With the window open
`GetDefaultSpecSkillLine()` answers **2810** and `GetSpecTabInfo()` answers `{enabled=false}`;
at login both answer nothing.

### Recipes, specialisation counts, Housing

- **Recipes.** `GetAllRecipeIDs()` 639 ids. `GetRecipeInfo(1260349)` a 28-field table with
  `hyperlink`, `categoryID`, `firstCraft`, `alwaysUsesLowestQuality`. `IsRecipeFirstCraft` false;
  `GetRecipeCooldown` `nil | false | 0 | 0`; `GetQualitiesForRecipe` nil for that recipe.
- **Specialisation counts.** `C_SpecializationInfo.GetNumSpecializationsForClassID` answers 3 for
  classes 1 to 10, 12 and 13; **4** for class 11; 0 for class 14. So a class with more than three
  exists and Family's model must allow it. It does **not** settle the *Devourer* of §11: which
  class each id is was not asked, and `C_CreatureInfo.GetClassInfo` is present and would say.
- **Housing.** `C_Housing.GetMaxHouseLevel()` answers **12**, which is §10's claim now read from
  the client instead of a page. `GetHousingAccessFlags()` 0, `GetPlayerOwnedHouses()` nothing,
  `GetCurrentHouseInfo()` nil - the unpurchased account. The census lists thirteen `C_Housing*`
  and `C_House*` namespaces.
- **The merchant is not ready at its own event.** Asked at `MERCHANT_SHOW`:
  `MerchantFrame:IsShown()` false, `GetMerchantItemLink(1)` nothing, `C_MerchantFrame.GetItemInfo(1)`
  an 8-field table with no `name`. Two seconds later: shown, the link is *Tough Hunk of Bread*, and
  the table has 9 fields with `name`. Worth holding against the Mists innkeeper that answered
  nothing (§6).

### What version 6 did not answer, and why

**No currency is named anywhere in the run.** The Catalyst question of §11 is exactly what the
currency list was read for, and every currency came back as an id and eleven booleans.
`showTable` prints a table's keys sorted and stops at twelve; a currency has twenty-five, and
`name`, `quantity` and `maxQuantity` all sort past the cut, which ends in a `...` that reads like
*more of the same*. Fixed in version 7 - the currency calls now ask for thirty keys - and it needs
one more login to answer. L-201.

### The Mists control could not be taken: version 6 crashes that client

Two launches, the same crash both times, 28 seconds into the world. From the log
(`2026-09-19_22.49.38_Crash_27336.txt`, build 69585, interface 50504,
Eccebombo-Mirage Raceway):

    Exception: ACCESS_VIOLATION ... referenced memory at "0x0000000000000000"
    #3 FamilySurface.lua:234  name="C_Housing.GetMaxHouseLevel", shown=""
    #4 FamilySurface.lua:343  word=nil, space="C_Housing", name="GetMaxHouseLevel"
    #6 FamilySurface.lua:470  interface=50504, who="Eccebombo-Mirage Raceway"

**The faulting call is `C_Housing.GetMaxHouseLevel()` with no arguments** - the same call that
answers 12 on Midnight. Frames 2, 5 and 7 are all `pcall`, and they caught nothing: a native null
dereference is not a Lua error. `professionLines` at `:468` completed before the sweep reached
`C_Housing` at `:470`, so it is not implicated and is unchanged.

So **Mists has a `C_Housing` namespace too**, and its functions are stubs that do not survive
being called. That is a reading about Mists worth keeping: a namespace existing on a Classic
client says nothing about the feature being there, which is `Capabilities.lua`'s thesis arriving
by a new road.

**Version 7** gates the sweep to interface 120000 and up, records a line saying so when it is
skipped, and adds `tools/FamilySurface/selftest.lua`, which fires `PLAYER_LOGIN` on both numbers
without a client. L-200.

## 13. A brief on the modern API, relayed 2026-09-19

**Hypotheses, not evidence**, under the rule of §8. Relayed by Alberto, who did not name its
source and said what it is for: *these are hints, all to be verified by us to convert into
facts.* So nothing here enters `Capabilities.lua`, a harness stub or Family's data until a client
shows it; what it does is steer what the next probe asks.

Its shape: everything moved into `C_` namespaces, calls answer one table instead of several
values, and Midnight returns unreadable *Secret Values* in combat and in instances. Then a
module-by-module list, taken from the alt-manager addons it is written about, of what to
call for each category.

### Checked against §12's run, and agreeing

| The brief says | The client said |
|---|---|
| the old quest log calls are gone | `GetNumQuestLogEntries`, `GetQuestLogTitle` absent |
| `GetFactionInfo` was removed | `GetFactionInfo`, `GetNumFactions` absent |
| the old auction house is gone | `GetNumAuctionItems` absent; `C_AuctionHouse.GetOwnedAuctionInfo(1)` answers a table with `itemKey`, `buyoutAmount`, `quantity`, `status` (§5) |
| `GetTradeSkillLine` is dead, use `GetBaseProfessionInfo` | both forms of the old call absent; the new one answers a table (§12) |
| quests come through `C_QuestLog.GetInfo` | `GetInfo` is in the namespace's listing |

### Checked, and the client says otherwise

1. **"Almost every loose `Get…` has been removed."** **99 of the 278 globals Family reads are
   absent; 179 answer.** `GetMoney`, `UnitXP`, `GetInventoryItemLink`, `GetSpecialization`,
   `GetSpecializationInfo`, `GetCategoryList`, `GetInboxNumItems`, `GetMerchantNumItems` all
   answer on Midnight. The removals cluster - quests, reputation, the old auction house,
   professions, talents, glyphs, the bank - and leave equipment, money, mail, the merchant and
   the unit calls alone.
2. **"Midnight returns tables where the old API returned several values."** Not a property of the
   client. Mists already answers `C_Container.GetContainerItemInfo(-1, 1)` with a table carrying
   `itemID` (§5), and Midnight still answers `GetSpecializationInfo(1)` with
   `259 | "Assassination" | …`. It is per call, which is why `Capabilities.lua` is a table and not
   a version number.
3. **"The warband bank is bag ids 13 to 17."** §6 settled it by sweeping the ids and matching
   them against Alberto's screenshots of every tab: containers **6 to 11** are the character's six
   tabs in order and **12** is the warband tab. The measurement stands and the brief does not.
4. **`C_ClassTalents.GetTraitTreeIDsForClass` does not exist.** `C_ClassTalents` is one of the
   namespaces the run listed in full - 31 functions - and the tree call it holds is
   `GetTraitTreeForSpec(specID)`, beside `GetConfigIDsBySpecID` and `GetActiveConfigID`.

### Not checkable from this run, and the reason

The probe lists the functions of the namespaces Family already uses and of those matched by a
brief's word (decision of 2026-09-19). The brief names five that are neither, so the census knows
only that they exist and how many functions each holds:

| Namespace | Functions | What the brief wants from it |
|---|---|---|
| `C_Reputation` | 27 | `GetNumFactions`, `GetFactionDataByIndex` |
| `C_MajorFactions` | 12 | `GetMajorFactionData`, for renown |
| `C_Bank` | 23 | `FetchPurchasedBankTabIds`, and `Enum.BagIndex.AccountBankTab_*` |
| `C_WeeklyRewards` | 21 | `GetActivities` |
| `C_MythicPlus` | 21 | `GetRunHistory` |

**Reputations are the one Family already ships**, so that namespace is the first the code step
hits, and naming it for the next probe is the move already made for `C_MerchantFrame`.

### What the brief adds that was not written down here

- **Secret Values in combat and in instances.** The most valuable line in it, because it is the
  one that would fail quietly: a scan that runs while the player is fighting could read back
  something unreadable and write a well-formed record of nothing over a real one, which is
  **L-019** arriving from a new direction. Nothing in this repository has asked the client about
  it. The probe is cheap and is a comparison, not a lookup: ask the equipment, talent and
  container calls once out of combat and once in it, write both down, and see whether the answers
  differ. The brief's own remedy - hold a scan until `PLAYER_REGEN_ENABLED` - is a change to
  Family and is not made until the reading says it is needed.
- **`recipeInfo.learned`**, the field it says to filter recipes by. §12's `GetRecipeInfo` answer
  has 28 fields and the run wrote down 12; `learned` sorts past the cut. L-201 a second time, and
  the `keys` count added in version 7 for currencies belongs on this call too.
- **Account-wide against per-character.** The brief's closing point: warbank, renown, transferable
  currencies and mounts belong to the account, not the character, so a record keyed by character
  is the wrong shape for them. Family is character-keyed throughout. **This is a question for the
  specification and therefore Alberto's**, and it is one of the three below.

### What probe version 8 asks of it

Built the same day, on Alberto's *you should create a probe checking all of those hints*. Every
claim above that a client can settle is now asked, and the safety rule of L-200 decides how:

- **The six namespaces, listed on every client** - `C_Reputation`, `C_MajorFactions`, `C_Bank`,
  `C_WeeklyRewards`, `C_MythicPlus`, `C_PetJournal`. Listing calls nothing and costs nothing, and
  it settles most of the brief by itself: *is `GetFactionDataByIndex` there* is a question about a
  name. Filed as `(brief)` in the namespaces.
- **A hand-written call into each, on Midnight only** - `C_Reputation.GetNumFactions()` and
  `GetFactionDataByIndex(1)`, `C_MajorFactions.GetMajorFactionIDs()`,
  `C_WeeklyRewards.GetActivities()`, `C_MythicPlus.GetRunHistory(false, true)`,
  `C_PetJournal.GetNumPets()`, `C_ClassTalents.GetActiveConfigID()`, and
  `C_Bank.FetchPurchasedBankTabIds(Enum.BankType.Account)`. Not on a Classic client: this
  repository has never seen one of them answer, and a first call is exactly what took Mists down.
  Filed as `brief`.
- **`C_QuestLog.GetInfo(1)` everywhere**, because that namespace is one Family already uses and
  an index is the argument the absent `GetQuestLogTitle(1)` took.
- **`Enum.BagIndex` and `Enum.BankType`, read as tables.** The brief puts the warband bank at
  `AccountBankTab_1`; §6 found bag 12 by sweeping ids against screenshots. Two readings of one
  thing, and they agree or one is wrong.
- **Secret Values, as a comparison.** Thirteen reads - money, level, class, an equipped link, an
  item, the specialisation, the talent reader, two container calls, the quest call - taken at
  login as `combatOut` and again two seconds into a fight as `combat`, with
  `InCombatLockdown()` written beside each. Nothing is assumed about how an unreadable answer
  prints: if the two differ, that is the finding, and if they do not, that is also the finding.
- **`GetRecipeInfo` widened to 40 keys**, so `learned` survives being written down.

### The three shape questions 5.0.0 now waits on

Alberto, 2026-09-19, asked whether the differences are large enough to want a Family of its own
for Midnight, and **deferred the answer until they are counted rather than described** (see
`DECISIONS.md`). The call-level differences are small and measured. What is not counted is the
shape, and these are the three that decide it:

1. **Professions as parent and child.** Measured in §12 - 157 lines, a parent on every one. What
   it costs Family's one-rank-per-profession model is not measured.
2. **Records that belong to the account and not the character.** Unread: `C_Bank`,
   `C_MajorFactions` and the transferable flag on a currency are all in the table above.
3. **Secret Values in combat.** Unread, and the only one of the three that could make a scanner
   silently wrong rather than merely incomplete.

## 14. A second brief, relayed 2026-09-20, and what version 9 asks of it

Alberto relayed a second brief the day after the first: twelve numbered domains, each with the
events it says an addon listens to, whether it is supported on the old clients, and how the call
differs between Midnight and the rest. It enters here under the same rule as the first and as
wow-professions.com - **hypotheses, never evidence**. Nothing from it reaches `Capabilities.lua`,
a harness stub or Family's data until a client answers. Its prose is not quoted here: a relayed
brief is an inbound vector for a name the tree must not carry, and one already rode in once (L-016).

### How much of it was already being asked

Counted rather than judged, name by name, against the generated list in `Surface.lua` and the
hand-written calls in version 8 of the probe:

| | already asked | new |
|---|---|---|
| functions and namespaces (51 named) | 33 | 18 |
| event names (30 named) | 17 | 13 |

So two thirds of the brief was already in the run Alberto is about to take. That is the useful
number: it says the first brief and this one describe the same client, and it says where the
thirty-one names that are left actually are.

### What it claims that this file has already measured

- **That Retail answers with tables where the old clients answer with several values.** Already
  refuted as a property of the client in §13: Mists answers `C_Container.GetContainerItemInfo`
  with a table, and Midnight still answers `GetSpecializationInfo(1)` with six values. It is per
  call. This brief repeats the claim domain by domain, and it is wrong the same way each time.
- **That the warband bank is reached through `Enum.BagIndex.AccountBankTab_1`.** §6 measured
  container **12** against Alberto's screenshots, and version 8 already reads the enumeration as
  a table so that the two readings can be held against each other.
- **`C_Reputation`, `C_MajorFactions`, `C_WeeklyRewards`, `C_MythicPlus`, `C_PetJournal`.** All
  five are already the namespaces version 8 lists on every client and calls on Midnight (§13).
- **`BAG_UPDATE`.** Recorded here because it looks like a gap in the generated list and is not:
  Family listens to `BAG_UPDATE_DELAYED` on purpose - `addons/Family/Core.lua:690` says why, and
  `Scanners/Bags.lua:463` and `Scanners/Bank.lua:399` are where it is done - and that name *is*
  in the list. The brief names the un-coalesced event; Family does not want it.

### What is genuinely new, and what version 9 does with it

Four domains Family has never recorded, none of which the generated list can reach, because that
list is generated from what Family already calls:

| Domain | New names | Asked how |
|---|---|---|
| PvP standing | `UnitHonor`, `UnitHonorMax`, `UnitHonorLevel`, `UnitPVPRank`, `GetPVPRankInfo`, `GetPVPLifetimeStats`, `GetPVPSessionStats`, `GetPVPYesterdayStats` | looked up everywhere, called on Midnight only; honour and conquest asked by id (1792, 1602) everywhere, since the call is one Family already makes and only the id is new |
| Raid lockouts | `GetNumSavedInstances`, `GetSavedInstanceInfo` | the same |
| Collections and mission tables | `C_Garrison`, `C_ToyBox`, `C_Heirloom` | listed by name on every client, called nowhere: a call into them needs a follower type or a filter that nothing here has measured, and naming one would be guessing |
| The client constants | every `WOW_PROJECT` global | swept **by prefix** and read as values; naming the three the brief gives is how a fourth is missed |

Plus the thirteen event names, asked with `RegisterEvent` in a `pcall`, which is how the other
136 literals are asked and how `Family:RegisterEvent` itself asks. They go into the same block as
those 136 rather than one of their own, so that the report compares them against the control
without being taught anything new - and a name no Family file mentions prints as `(no file found)`
beside it, which records where it came from without a second list saying so. **The events block is
149 names in version 9**, and §12's count of refusals was against 136.

One thing was nearly lost here and is worth the paragraph. The first version of these blocks wrote
lines like `UnitHonorLevel is function`. `tools/surface.py` keys a line by what stands before a
`)` and compares the words after it (`tools/surface.py:156`), so those lines were keyed by their
whole text, which differs on every client, and **every comparison the report makes dropped them
silently**. The block would have been in the file, and the report would have said nothing about
it. The lines are now `UnitHonorLevel (looked up) is function`, and `absent` rather than `nil`
because the report forgives a nil as *this character happens to hold nothing*. Checked end to end
by running the probe against stubs, writing the saved variables out and asking
`tools/surface.py --report` for the difference, which now prints both directions. L-203.

The division - **a name is looked up on every client, a call is made only where the sweep is
allowed** - is L-200's rule and not a new one. It also happens to be the right division for this
brief in particular, because most of what it asserts is *supported in all versions*, and that is
a claim about a name existing, which a lookup settles for nothing.

**`C_Traits` and `C_ClassTalents` are not in the table** because the word list the discovery sweep
already carries (`Trait`, `Talent`) matches them by name, so both were listed in full by version 6
- which is how §13 could say that the tree call is `GetTraitTreeForSpec(specID)` and not the one
the first brief named.

### The one claim worth more than the others

That a lockout is read by the same two calls on **every** client. If it holds, it is the only
domain in either brief that would need no fourth column at all - one reader, four clients, no
capability entry. If it does not hold, that is worth knowing before anybody designs for it. It
costs two lines in the run either way.

### Where the brief argues against this branch

It closes with an implementation suggestion: branch on `WOW_PROJECT_ID`, one arm per client
family, and keep two separate shapes in the saved variables. **The first half is refused.** This
branch goes by the capability table and `Family:TryCall`, never by a branch on which client is
running (`CLAUDE.md`, step 3 of the order); a client id says what the build is and not what the
build can do, which is the whole thesis of `Capabilities.lua` and the reason four of its entries
exist at all. What the constant *answers* on each client is still a fact, and version 9 writes it
down - reading it and branching on it are different acts.

The second half - that PvP is two different records rather than one with holes - is a question
for the specification and therefore Alberto's, and it is the same question as the account-wide
one in §13. It is in `docs/BACKLOG.md` with the other three domains rather than decided here.

## 15. What Midnight owes the features `main` is building (2026-09-20)

`main` is not standing still while this branch measures. On 2026-09-20 it added four entries and
revived a fifth, and it is building each of them **to what is supported up to Mists and no
further** - Alberto, the same day. Every one of them therefore arrives here as a fourth column to
fill, and the cheapest moment to know what that costs is before the code is written, not at the
5.0.0 merge.

### Why this section is here and not in `docs/BACKLOG.md`

Because the numbering is main's and a Midnight entry in it collides. It already did: on
2026-09-20 both sides wrote a `## 92.` on the same day, main's *The quests a character has
already finished* and this branch's, and the merge would have had to choose between two entries
with one number. `BACKLOG.md` is where `main` lists what Family will do; what **Midnight** owes
those features is a fact about this branch and belongs in this file, which `main` does not have.
The Midnight-only entry written that day was moved here rather than renumbered, because
renumbering solves one collision and moving solves the class.

### The five, and what each rests on

| main | What it is | Midnight's part |
|---|---|---|
| 5 | Honor: rank, the week's progress, what is left of the cap. Deferred 2026-09-12, measured again 2026-09-20 | The whole shape changes: §14's brief says honour and conquest are ordinary currencies and the honour *level* belongs to the account. Probe version 9 asks both |
| 92 | The quests a character has already finished | Which of the four completion calls Midnight carries, and whether the account-wide one answers - Family already asks `IsQuestFlaggedCompletedOnAccount` here (§12) |
| 93 | Instance lockouts, and when each resets | Whether the same two calls answer, which §14 calls the one claim worth more than the others |
| 94 | Rested experience since a character was put away | `GetXPExhaustion` is already asked here; `IsResting` and the two events are not |
| 95 | A currency read from the older list is filed under its name, not its id | Settled on Burning Crusade by **position** - see below. Midnight's list is `C_CurrencyInfo`'s and answers a table with named keys, so the position cannot carry over and the question has to be asked again here |

### The debt, counted rather than described

Those five entries rest on eighteen names between them. Measured on 2026-09-20 against
`Surface.lua` and version 9's hand-written calls: **ten are asked on Midnight and eight are not.**

| Asked by version 9 | Not asked |
|---|---|
| `C_QuestLog.IsQuestFlaggedCompleted`, `GetNumSavedInstances`, `GetSavedInstanceInfo`, `UPDATE_INSTANCE_INFO`, `GetXPExhaustion`, `PLAYER_UPDATE_RESTING`, `UPDATE_EXHAUSTION`, `GetCurrencyListLink`, `GetCurrencyListInfo`, and the honour block of §14 | `GetQuestsCompleted`, `C_QuestLog.GetAllCompletedQuestIDs`, `QueryQuestsCompleted`, `GetDailyQuestsCompleted`, `QUEST_QUERY_COMPLETE`, `GetNumSavedWorldBosses`, `GetSavedWorldBossInfo`, `IsResting` |

Version 9 is **not** being extended to cover the eight - Alberto, 2026-09-20 - so they are asked
in the run after those features land rather than in the one about to be taken. The cost of that
choice is one more client run, and it is written here so that it is a choice and not a surprise.

### Which probe owns which fact

Two probes now ask overlapping questions of Mists: `tools/FamilyProbe` on `main`, and
`tools/FamilySurface` here. The rule, so that one client does not end up with two answers in two
documents:

- **What Era, Burning Crusade and Mists answer belongs to `FamilyProbe` and is written in
  `docs/DATASOURCES.md`.** This file cites it and does not re-derive it.
- **What Midnight answers, and the Mists control taken beside it, belongs to `FamilySurface` and
  is written here.**
- Where both have measured the same thing, **two readings that agree are a check and not waste**;
  two that disagree are a finding, and the disagreement is written down before either is believed.

**And the limit of that ownership, which is the whole point of it.** `main`'s mandate is Era,
Burning Crusade and Mists, and nothing after - Alberto, 2026-09-20. So everything it measures is,
for this branch, **a starting point and never a conclusion**. *`GetQuestsCompleted` answers in
4.0 ms on Era* is a fact about Era. It is a reason to ask Midnight the same question and a
description of what a good answer looks like; it is not evidence that the call is there, that it
is named that, or that it answers the same way. Some of these calls will turn out identical after
Mists and some will not, and which is which is not knowable from this side of the measurement -
that sentence is `Capabilities.lua`'s thesis word for word, and the reason a fourth column is data
and not a guess. **A row of this file may cite a `main` measurement as the question. It may never
cite one as the answer for Midnight.**

This is also why the Mists control stays even though `FamilyProbe` already asks Mists. The
control's job is not to know Mists - `DATASOURCES.md` knows Mists - but to sit beside the Midnight
reading, taken by **the same probe, with the same arguments, in the same run**. Two probes asking
one client the same question with arguments chosen separately can differ for reasons that are
about the probes, and a difference read as a difference between clients would be a wrong answer
arrived at honestly.

`main` has already written its half of this: `DATASOURCES.md`, *What the second brief adds*, files
the honour ids 1792 and 1602 and the three unit calls as *the first thing to probe on the
`midnight` branch*, having asked the three unit calls on its own three builds. It also found
`GetArenaCurrency` **absent on 2.5.6**, which makes the standalone route `Scanners/Currencies.lua`
carries for it dead code **on the three clients Family ships against today** - and says nothing
about whether Midnight has it. Version 9 asks that call on every client for exactly that reason.
What the finding saves this branch is the re-discovery, not the question.

### A worked example of the limit, landed the same day

`main`'s `6047f8f` settled backlog 95 on Burning Crusade, and it is worth reading as the shape of
what will keep arriving here. `GetCurrencyListLink` answers nothing at all on 2.5.6, so the only
route Family had to a currency's id gave none and honour was filed under its own name in one
language. The id turned out to be **the twelfth value of the row** the older list answers with -
1901, held against two characters whose honour differed while the twelfth value did not, which is
how an identity is told from a figure.

That is a **positional** reading of a list of loose values. Midnight does not have that list: it
answers `C_CurrencyInfo.GetCurrencyListInfo` with a table of named keys, which version 9 already
reads thirty keys deep. So the measurement is exact, hard-won, true of 2.5.6 - and the one thing
it cannot be is the answer here. What travels is the question it sharpens: *where does Midnight
put a currency's id, and is it there at all?* What does not travel is *the twelfth value*.

Held the other way round, the same commit is a warning about this branch's own code: a scanner
that read position twelve because Burning Crusade puts it there would be a branch on the client
wearing the clothes of a measurement. The fourth column names the key; it does not count places.

## 16. What the client answered, 2026-09-20 — and the verdict on both briefs

The runs: **Midnight 12.1.0, build 69875, interface 120100**, character `Ahia-Chamber of Aspects`,
probe version 9, against the control **Mists 5.5.4, interface 50504**, `Eccebombo-Mirage Raceway`,
same version, same day. Both files hold older runs beside these and the wrong ones were read
first; `--report` now says so by itself (L-206). The saved variables stay out of the tree.

Against that control: **73 globals absent here and present there**, 0 namespace members absent,
7 literals Midnight refuses that Mists registers, 0 templates failing, **49 calls absent here and
answered there**, 33 namespace functions here and not there, and **12 calls both clients answer in
a different shape**.

### The one that could have made a scanner silently wrong, and did not

**Secret Values: no.** Twelve reads taken at login out of combat and again two seconds into a
fight - money, level, class, an equipped link, an item, the specialisation, the talent reader, two
container calls, the quest call - and **ten are identical**. The two that differ are
`InCombatLockdown()`, which is the flag itself and says `false` then `true`, and `GetMoney()`,
which went from 627950934 to 627950484: the character spent 450 copper. Nothing came back
unreadable.

This is the third of the three shape questions 5.0.0 waits on (§13), and it is answered in the
direction that costs nothing: **a scan that runs in combat reads what a scan out of combat reads**,
for every call Family makes. It is one character and one fight; it is not a proof that no call on
Midnight is ever a Secret Value. It is a measurement that the ones Family makes are not.

### The twelve that answer differently, and the one that matters

`GetTalentInfo(1, 1)` is the sharpest thing either brief turned up, and neither brief mentions it:

| | answer |
|---|---|
| Midnight | `22337 \| "Master Poisoner" \| 132108 \| false \| false \| 196864 \| …` |
| Mists | `"Speed of Light" \| 571558 \| 1 \| 1 \| 1 \| 1 \| …` |

Same name, same client-facing call, **the id and the name swapped places**. A scanner doing
`local name = GetTalentInfo(tab, index)` writes a number into a name field on one client and a
name on the other, and nothing anywhere goes red. `Scanners/Talents.lua` already inspects the
returns rather than unpacking them positionally - the note at its head says positional unpacking
has been wrong there twice - so Family survives this by a habit it learnt the hard way.

The others: `GetInventoryItemID` answers one value here and two there; `GetBuildInfo` seven there
and six here; the container sweep finds 6 to 10 holding 98 slots each here against Mists' own
arrangement; `WOW_PROJECT_ID` is **1** here and **19** there; and five of the twelve are the PvP
split below.

### Three calls that exist on Mists and throw

`GetNumTalentGroups()`, `GetNumTalentTabs()` and `GetNumTalents(1)` all answer
*"API unsupported in this version of World of Warcraft"* on 5.5.4 - in **all five** runs in the
control file, so this is as old as the client and not news. It is `Capabilities.lua`'s thesis in
one line: the symbol is there and the call is not. Family reads all three and calls all three
through `Family:TryCall` (`Scanners/Talents.lua:115`, `:129`, `:68`), and `readTrees` returns
`nil` when the count comes back 0 (`:157`), so the scanner is right. Checked by reading the code,
because a throw in a probe is not by itself a defect anywhere.

### The verdict on the second brief, domain by domain

| Brief | Verdict on Midnight |
|---|---|
| Inventory in `C_Container`, old globals gone | **Right.** `GetContainerNumSlots` and `GetContainerItemInfo` absent |
| Warband bank behind `Enum.BagIndex` | **Right in kind, wrong in value.** `AccountBankTab_1` = **12**, not 13. It agrees with §6's container sweep - two readings, one number |
| Mail almost unchanged since the beginning | **Right.** `GetInboxNumItems`, `GetInboxHeaderInfo` and `GetInboxItemLink` all answer |
| Professions rebuilt on `C_TradeSkillUI` | **Right in full.** `GetBaseProfessionInfo`, `GetAllRecipeIDs` (639 recipes) and `GetRecipeInfo(id)` all answer; `GetChildProfessionInfo` gives `parentProfessionID=202`; `GetNumTradeSkills` and `GetTradeSkillInfo` absent |
| Talents on `ConfigID`/`TreeID`, the old ones legacy | **Half wrong.** `C_ClassTalents.GetActiveConfigID()` answers 27781581, but `GetTalentInfo` is *still here* and answers in a different order (above). `GetNumTalentTabs` absent |
| Auction house rewritten, `C_AuctionHouse` | **Right.** Old `GetNumAuctionItems`/`GetAuctionItemInfo` absent; `GetNumOwnedAuctions` and `GetOwnedAuctionInfo` answer; the three `AUCTION_*_LIST_UPDATE` events are refused here and registered on the control |
| Quest log in `C_QuestLog` | **Right.** `GetNumQuestLogEntries` and `GetQuestLogTitle` absent; `C_QuestLog.GetInfo(1)` answers 26 keys |
| Reputations: old deprecated, `C_Reputation` + `C_MajorFactions` | **Right.** `GetNumFactions`/`GetFactionInfo` absent; `C_Reputation.GetNumFactions()` = 67; `C_MajorFactions` holds `GetMajorFactionData` among its 12 |
| Currencies in `C_CurrencyInfo`, with a transferable flag | **Right, under another name.** The field is `isAccountTransferable`, with `transferPercentage` beside it - 80 for honour |
| Collections account-wide | **Right.** `C_PetJournal` 80 functions, `C_ToyBox` 26, `C_Heirloom` 24; `GetNumPets()` answers 2069 \| 599 |
| Garrisons Retail-only, `C_Garrison` | **Right.** 227 functions |
| Lockouts the same two calls everywhere; Vault and M+ Retail-only | **Right, and it is the best news in the brief.** `GetNumSavedInstances` and `GetSavedInstanceInfo` are here and answer. `C_WeeklyRewards.GetActivities()` gives 10 tables, `C_MythicPlus.GetRunHistory(false, true)` an empty one |

### Where it is wrong, in five places

1. **The warband bank is 12**, not 13 to 17.
2. **`GetTalentInfo` did not go**, and answers in a different order - the case above.
3. **The old PvP stat calls are not Classic-only.** `GetPVPLifetimeStats` (2078 \| 9),
   `GetPVPSessionStats` and `GetPVPYesterdayStats` all answer on Midnight.
4. **"Honour is an ordinary currency" is true and incomplete, in a way that would have cost us.**
   Currency 1792 is here and is named *Honor*, `maxQuantity` 15000, `isAccountTransferable` true
   at 80 per cent - and on this character it answers **`quantity = 0`** while
   `UnitHonor("player")` answers **5394**. Two readings of one word. A scanner written from the
   brief alone would record zero for a character with 5394. On Mists, `FamilyProbe` reads the same
   id as `name = "Honor Deprecated 3"`, `currencyID = 0`: the same number is a different thing per
   client, which is why the fourth column is data and not a version check.
5. **`C_Bank.FetchPurchasedBankTabIds` does not exist.** The namespace is here with 23 functions;
   that name is not among them.

### The PvP split, which is an exact mirror

| | Midnight | Mists |
|---|---|---|
| `UnitHonor`, `UnitHonorMax`, `UnitHonorLevel` | there - 5394, 5500, 3 | **absent** |
| `UnitPVPRank`, `GetPVPRankInfo` | **absent** | there |
| `GetPVPLifetimeStats`, `GetPVPSessionStats`, `GetPVPYesterdayStats` | there | there |

Confirmed from both sides and by both tools: `FamilyProbe` on `Luga-Mirage Raceway` reports the
same three unit calls absent on Mists. **Two instruments, two characters, one answer** - the first
time the ownership rule of §15 has paid, and it paid as a check rather than as duplicated work.

### What the probe did to the client, which is not a finding but must be read beside these

Version 9's sweep called ten actions on Alberto's character - `C_AuctionHouse.CancelAuction()`
among them - because its name filter read `Can` as a prefix and caught `Cancel` (L-205). Nothing
is known to have been changed by any of them. This section said for some hours that a live auction
had been cancelled, on the strength of an empty owned-auction list and a letter in the inbox;
Alberto had cancelled it himself, to put something in the inbox for the probe to read, and
`CancelAuction()` with no argument cancels nothing. That invented cause, and the leading question
that appeared to confirm it, are L-207. The readings above are unaffected either way: they are
reads, and the file carries each with its own answer.

### Still to do for step 1

**Probe version 7** re-takes what version 6 could not: the **Mists control** for the census and the
surface, which the crash cost; and, on Midnight, the **currency names** for §11's Catalyst. Nothing
else about it changed, so the Midnight readings above stand and the run is for those two.


1. ~~Where the bank is on Midnight~~: containers 6 to 11 are the character's six tabs in order,
   and 12 is the warband tab (§6), settled against Alberto's screenshots of every tab.
2. ~~What replaces `GetMerchantItemInfo`~~: `C_MerchantFrame.GetItemInfo` (§6).
3. ~~A Mists vendor, as the control for the merchant calls~~: obtained with version 4 (above).
   An innkeeper's goods, reached through its dialog, answered nothing once, and why is not
   isolated. Of the merchant calls Midnight still has, `GetMerchantItemLink`
   answered an ordinary link and `GetMerchantItemCostInfo` 0 for a vendor's bread. What a
   Mists vendor with goods would add is the shape of those two on the client where Family
   already works.
4. ~~Where the profession specialisations and their knowledge points live~~: `C_ProfSpecs`,
   found by the sweep rather than named from memory (§12).
5. ~~Whether Midnight's per-expansion lines are child skill lines~~: they are, with a parent
   named on every one of the 157 (§12). What is still open is whether **Mists' *Way of* lines
   answer the same calls**, which would make one model serve both - backlog 24 measured them as
   child lines, and no client has been asked with these calls.
6. **What the Catalyst's charges are called**, and whether they are in the currency list at all.
   Version 6 read the list and threw the names away; version 7 keeps them (§12).
7. **Which class id is which on Midnight**, so that the specialisation counts can be read as
   classes. `C_CreatureInfo.GetClassInfo` is present and is one line.
8. ~~The Mists control run~~: taken 2026-09-20 with the long list, `Eccebombo-Mirage Raceway`,
   probe version 9 (§16). The census has its control at last.
9. ~~Whether a scan reads Secret Values in combat~~: **no** (§16). Ten of twelve reads identical
   in and out of a fight; the two that differ are the combat flag itself and 450 copper spent.
10. ~~What `C_Reputation`, `C_MajorFactions` and `C_Bank` hold~~: 27, 12 and 23 functions, listed
    in full (§16). `GetFactionDataByIndex` and `GetMajorFactionData` are there;
    `C_Bank.FetchPurchasedBankTabIds` is not.
11. **Whether a record belongs to the account or the character** on Midnight - the warband bank,
    renown, and the transferable flag on a currency. A question for the specification once the
    probe has read them, and one of the three that 5.0.0's shape waits on.
12. ~~Whether a lockout reads the same on Midnight~~: **yes** - `GetNumSavedInstances` and
    `GetSavedInstanceInfo` are there and answer (§16), and `FamilyProbe` reads them on Mists.
    Era and Burning Crusade are `main`'s to confirm.
13. **What PvP standing is on each client** (§14): whether honour and conquest are ordinary
    currencies on Midnight, whether the account-wide honour level is readable, and which of the
    old rank calls survive where. Presence is answered everywhere by version 9; what the calls
    answer is Midnight-only until one of them has been seen to survive.

## 17. What the client refused, and the sweep that asked it (2026-09-20, version 12)

The run of version 12 on `12.1.0` build 69875, two characters on Chamber of Aspects, answers the
question the blocked-action dialog has been asking since the 19th: **which call.** The client
names none - it says `UNKNOWN()` every time - so the answer comes from the probe's own
bookkeeping, which records what it was calling at the instant the event arrived.

**Eight calls, the same eight on both characters:**

    C_HouseExterior.GetFixtureDebugInfoForGUID      C_HousingDecor.GetDecorDebugInfoForGUID
    C_HouseExterior.GetHoveredFixtureDebugInfo      C_HousingDecor.GetHoveredDecorDebugInfo
    C_HouseExterior.GetSelectedFixtureDebugInfo     C_HousingDecor.GetSelectedDecorDebugInfo
    C_HousingCatalog.GetCatalogEntryDebugInfoForID  C_HousingDecor.GetAllPlacedDecor

**It is not an unbought expansion, and the run settles that on its own.** The first reading of
these lines was that the housing API is not enabled on the account. Measured instead: the sweep
called **208** housing functions and **200 went through**; 292 lines in those namespaces answer
with a value (`GetHouseEditorAvailability() answers 50`, `IsHouseEditorActive() answers false`).
Of the 208, exactly **seven** hold `Debug` in the name and **all seven are refused**, with
`GetAllPlacedDecor` the eighth. No entitlement draws a boundary around the word `Debug`. And the
event says as much: `ADDON_ACTION_FORBIDDEN` is *only available to the Blizzard UI*, a
protection, not an absence - a missing function is recorded as `absent`, which is a separate
measurement this probe takes.

**The refusals were ours, not the client's fault and not Family's.** Family names no housing call
anywhere: `grep -r Housing addons/` answers nothing. Every one of these came from the probe's own
no-argument discovery sweep. Version 13 lists them and does not call them.

### And the thing the same run shows that nobody asked

The sweep chooses namespaces by whether the name holds one of the briefs' words. In this run that
reached **22 namespaces**, and two of them nobody meant:

| namespace | calls made | because |
|---|---|---|
| `C_AuctionHouse` | **53** | `House` sits inside *Auction**House*** |
| `C_AddOnProfiler` | 6 | `Prof` sits inside *AddOn**Prof**iler* |

On a character with live auctions. Nothing is known to have changed - every name called was a
`Get`, `Is`, `Can` or `Has` by the whole-word rule of version 10, and `CanCancelAuction` is a
predicate and not the action - and that is again luck rather than a property of the probe, which
is the second time in two days this sentence has had to be written (L-205).

**No rule of position fixes it.** The word is in the middle of the name in the two that are
unwanted and equally in the middle in `C_LegendaryCrafting` and `C_ClassTalents`, which are
exactly what the brief asked about. So version 13 stops deciding this with a pattern: `SPACES`
names the twenty namespaces that are called into, read off this run's census. The words still
run, and a namespace they find that the list does not hold is **listed and not called**, with a
line in the run saying so - which is how the next build's new namespace gets seen and decided
on, instead of swept.
