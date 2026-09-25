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

### ~~Not checkable from this run~~ - all five were named to the probe, and all five answered

The probe lists the functions of the namespaces Family already uses and of those matched by a
brief's word (decision of 2026-09-19). The brief named five that were neither, so at the time
the census knew only that they existed and how many functions each held. **Version 8 named them,
and the run of 2026-09-20 lists every one in full**, so the column on the right is now a verdict
rather than a want:

| Namespace | Functions | What the brief wants from it | The client |
|---|---|---|---|
| `C_Reputation` | 27 | `GetNumFactions`, `GetFactionDataByIndex` | **both there** |
| `C_MajorFactions` | 12 | `GetMajorFactionData`, for renown | **there** |
| `C_Bank` | 23 | `FetchPurchasedBankTabIds`, and `Enum.BagIndex.AccountBankTab_*` | **there as `FetchPurchasedBankTabIDs`** - the discovery is right and the spelling is not, which in Lua is the same as absent |
| `C_WeeklyRewards` | 21 | `GetActivities` | **there** |
| `C_MythicPlus` | 21 | `GetRunHistory` | **there** |

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
11. ~~Whether a record belongs to the account or the character~~: **answered, 2026-09-21,
    Alberto - the account is a second kind of record.** Family has been character-keyed
    throughout; it learns one more subject. A fact that belongs to the account is written once,
    under the account, and shown as *Warband* rather than under a character's name. The measured
    cases are container 12 (§6: the same first item on both characters, because it is one shelf
    seen twice), `isAccountTransferable` with `transferPercentage` on a currency, renown and the
    collections. **The same answer settles §14's PvP half**, which was the same question asked
    of honour. What it costs is a schema, a migration of what is already stored, and every place
    that assumes a character key; what it buys is that *who has this* stays true and a family
    total stops counting one shelf once per character. It is step 3's work and does not block
    step 2.
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

### What version 13 answered on its first run (2026-09-20, `Ahia`)

Three predictions, and the arithmetic closes:

- **No refusals.** The `blocked` block is empty where version 12's held eight. The three lines
  naming what was listed and not called are there instead: `C_HouseExterior` 3,
  `C_HousingCatalog` 1, `C_HousingDecor` 4.
- **472 no-argument calls became 405, across 20 namespaces instead of 22.** The difference is
  67 = 53 + 6 + 8, which is `C_AuctionHouse`, `C_AddOnProfiler` and the eight refusals, and
  nothing else moved.
- **And the off-list line found a third namespace on its first run, which is what it is for.**
  `C_TradeInfo` - reached by `Trade`, which was meant for `C_TradeSkillUI`. It holds
  `AddTradeMoney`, `PickupTradeMoney`, `SetTradeMoney` and `ShouldShowTradeOfferWarning`: the
  player-to-player trade window, and three of the four move money. **Nothing was ever called in
  it**, because none of the four begins with a read word - so version 12 swept a money-moving
  namespace and was spared by the naming of its functions. That is luck for the third time in
  two days.

It was missed when `SPACES` was written because that list was read off the namespaces the
earlier run had *made calls in*, and `C_TradeInfo` made none - enumerating from the effect
rather than from the matcher, which is L-204's shape once more. The line that reports an
off-list namespace is what caught it, on the first run after it was written, which is the whole
argument for keeping the words as a net after taking them out of the decision.

## 18. Step 2 begins: the harness learns a fourth pretend client (2026-09-22)

`tests/Harness.lua` had no 12.x build in it and stubbed `5.5.4 / 50504` at four sites. It now
carries a fourth pretend client - `12.1.0`, build 69875, interface 120100 - beside the three
Classic ones, which are not edited to make room.

**Every symbol in it is measured, not expected**, read off the version 13 run on
`Ahia-Chamber of Aspects`: `KEYRING_CONTAINER`, `BANK_CONTAINER`, `GetCurrencyListSize`,
`GetNumGlyphSockets`, `C_GlyphInfo` and `GetNumTalentGroups` are **absent**;
`GetNumGuildBankTabs`, `C_GuildBank`, `GetAchievementInfo`, `C_CurrencyInfo` and
`GetNumSpecGroups` are **present**, and `GetNumSpecGroups()` answers **1**.

What the seven checks pin is the state Family is in *before* the fourth column exists.
`expansion()` is `interface / 10000`, so Midnight is 12 and no row of the table has a 12: every
feature answers false, the client is named `interface 12`, and nothing is claimed for a client
nobody has measured Family against. That is the safe direction and it is also wrong for three
features - achievements, the guild bank and currencies - whose symbols are on the client and
whose diagnostics say so by name. **Those three disagreements are step 3's work written as
checks rather than as a paragraph**: when the fourth column lands they stop disagreeing, and
the check is what will say so.

Two more are pinned because they are right for the right reason - the keyring and glyphs are
off *and* their symbols are gone - and one because it is the one a looking probe would get
wrong: dual specialisation's symbol is present and answering, and calling it says one group,
which is no.

Three mutations recorded, each checked to be caught by the check meant to catch it: reading an
unknown interface as the newest known client, giving a missing column every feature, and
dropping the diagnostics where the table has no column.

### The second slice: a bag scan on the fourth client (2026-09-22)

`Scanners/Bags.lua` chooses its route at the top - `local container = C_Container or {}` - and
every function it needs is present and answering on Midnight, measured: `GetContainerNumSlots`,
`GetContainerNumFreeSlots`, `GetContainerItemInfo`, `ContainerIDToInventoryID`,
`GetContainerItemCooldown`, `GetContainerItemLink`, with `NUM_BAG_SLOTS` at 4 as on the other
clients. `slotContents` already reads both answer shapes, the table and the older ten returns.

So the harness loads that file a second time, under the Midnight build with no loose container
global present, into a private table that reads through to the real Family for everything but
the three things that would reach across the rest of the run: no events are registered, the
member has a name of its own, and the store is a recorder. Eight checks. The scan comes back
with 50 slots, 46 free, no special bag, and the ids and counts intact.

**The claim this section first made was too wide, and the measurement is what narrowed it.**
It said the checks proved Family reaches Midnight through `C_Container` where the loose globals
are gone. They do not: the harness's own base client is already built on `C_Container` and
defines no loose container global anywhere, so that route was covered before this slice
existed. Found by mutating the shim and watching an *Era* check go red rather than one of the
new ones. What the section adds is the Midnight build, the capability answers that come with it
- no keyring, so the bag order is one entry shorter - and a scanner loaded where the old names
are absent rather than merely unused.

**And it turned up a check that could not fail.** The mutation that makes every slot read as
empty crashed the run at `tests/Harness.lua`'s `payload.bags[0].slots[2].id == 2589` - an index
into a slot that is no longer there - so the gate exited non-zero, the mutator called the case
caught, and no failure was ever printed. True word, wrong reason. That check is now guarded and
says *slot 2 of the backpack is empty*, and the rule is L-208.

## 19. The brief's table hint, applied to the whole surface (2026-09-22)

Asked by Alberto whether the briefs were being used or filed: *"il fatto che molti metodi e api
rispondono con una tabella in midnight faceva parte dei suggerimenti iniziali. Li stai usando?"*
The answer had been **per slice** - each time a call was touched, its shape was checked - and
never across the whole surface at once. It is now, from the run already in hand.

**55 of the 331 calls the version 13 run answers hand back a table.** Of those, **12 are named
in Family's own sources**, and they are the only ones that can break anything:

| the call | where Family reads it | how it reads the answer |
|---|---|---|
| `C_Container.GetContainerItemInfo` | `Scanners/Bags.lua:71` | `if type(info) == "table"`, with the ten-return form kept beneath |
| `C_CurrencyInfo.GetCurrencyListInfo` | `Scanners/Currencies.lua:93` | `type(info) == "table" and not info.isHeader` |
| `C_TradeSkillUI.GetRecipeInfo` | `Scanners/Professions.lua:693` | `type(info) == "table" and info.learned` |
| `C_TradeSkillUI.GetAllRecipeIDs` | `Scanners/Professions.lua` | a list, walked as one |
| `C_Spell.GetSpellInfo` | `Names.lua:235` | table first, then the string form, then the old global |
| `C_AuctionHouse.GetBrowseResults` | `Scanners/Auctions.lua:1030` | `type(results) ~= "table"` returns, and the first row is type-checked too |
| `C_SpecializationInfo.GetTalentInfo` | `Scanners/Talents.lua` | the table form, through `TryCall` |
| `C_CreatureInfo.GetRaceInfo` | `Races.lua:251` | `type(info) == "table" and type(info.raceName) == "string"` |
| `C_Texture.GetAtlasInfo` | `Races.lua:296` | `type(info) == "table"` as the whole answer |
| `GetCategoryList` | `Scanners/Character.lua:563` | `type(categories) ~= "table" or #categories == 0` |
| `GetAutoCompleteRealms` | `Wide.lua`, `Guild.lua` | a list |

**Every one of the eleven already guards on the type.** Not one reads a table as though it were
the first of several returns. That is not luck: Mists answers several of these with a table
already, which is why §13's second brief claim - *Midnight returns tables where the old API
returned several values* - was recorded there as **false as a rule and true per call**.

**The twelfth is `C_MerchantFrame.GetItemInfo`, and it is a different kind of gap.** It answers
a table on Midnight and Family never names it: `grep -rc C_MerchantFrame addons/` is zero. That
is not a shape Family reads wrongly, it is a call Family does not make - the replacement for the
absent `GetMerchantItemInfo`, already listed in §6 as step 3's work. Worth separating, because a
sweep for shape faults will keep finding it and it is not one.

**What this changes about how the briefs are used.** A hint that turns out to be false as a rule
is not spent: it becomes a *question to ask of every call*, and the answer is a column in the
measurement rather than a sentence in a document. This audit is that column for one hint. The
same treatment is owed to the other claims in §13 and §14 that were recorded as *per call*
rather than settled.

## 20. The briefs, confirmed one function at a time (2026-09-22)

Alberto, on being shown §19: *"i suggerimenti che ti ho dato hanno forte probabilità di essere
esatti; è lavoro di scoperta già fatto, devi solo confermare se ci sono errori."* That is the
right framing and this file had not been using it - the briefs were being read as claims to
weigh rather than as findings to check off. So every function-level claim in §13 and §14 was put
to the run, by name.

**Seventeen claims. Sixteen right, one wrong, and the one that looked wrong was a spelling.**

| The brief names | The client |
|---|---|
| `C_Reputation.GetNumFactions`, `.GetFactionDataByIndex` | both there |
| `C_MajorFactions.GetMajorFactionData` | there |
| `C_WeeklyRewards.GetActivities` | there |
| `C_MythicPlus.GetRunHistory` | there |
| `C_PetJournal.GetNumPets`, `C_ToyBox.GetNumToys`, `C_Heirloom.GetNumDisplayedHeirlooms` | all there |
| `C_Garrison.GetOwnedBuildingInfo` | there |
| `C_TradeSkillUI.GetBaseProfessionInfo`, `.GetRecipeInfo` | both there |
| `C_QuestLog.GetInfo` | there |
| `C_Item.GetItemInfo`, `C_Spell.GetSpellInfo` | both there |
| `C_Bank.FetchPurchasedBankTabIds` | **`FetchPurchasedBankTabIDs`** - the function is exactly where the brief says, and the brief's capitals are not the client's. In Lua that is the same as absent, and it is the kind of error only a machine finds |
| `C_ClassTalents.GetTraitTreeIDsForClass` | **not there.** The tree call this client has is `GetTraitTreeForSpec(specID)`, beside `GetConfigIDsBySpecID` and `GetActiveConfigID`. The only claim of the seventeen that is wrong about the client rather than about its own spelling |

`C_Bank` also carries `FetchPurchasedBankTabData`, `FetchNumPurchasedBankTabs`,
`CanPurchaseBankTab` and `FetchDepositedMoney`, which is more of the warband bank than the brief
promised and is the answer to *how many tabs are bought* without a container sweep.

**The instrument was wrong first, and this section nearly reported it.** The first pass answered
*absent* for `C_Container.GetContainerItemInfo`, a call this branch has watched answer. The fault
was a dictionary keeping the last value for each namespace - the one-word presence line, `table`,
overwriting the listing of function names. Three known presences are now asserted before any
verdict is printed, and nothing is reported if one of them fails: L-202's rule, that a canary has
to run the same command as the thing it guards.

**What this leaves.** The briefs' function-level claims are now checked off rather than pending.
What remains open from them is not presence but behaviour - what `GetActivities` answers, whether
renown reads per account - and that is step 3's, one scanner at a time.

## 21. The route no client had ever taken (2026-09-22)

`Scanners/Currencies.lua` has carried `readModernList()` since the currency slice, and its own
comment says why it had never run: *not because any build here was seen using it*. Era and
Burning Crusade have no `C_CurrencyInfo` list calls; Mists has the namespace and not the calls,
and `tests/Harness.lua` asserts exactly that - `C_CurrencyInfo.GetCurrencyListSize == nil`.
**Midnight answers 49.** It is the first client this project has met that takes that path, and
until today the path was written, reviewed, gated and never once walked.

It works. Four checks on the fourth pretend client: the list answers where the loose calls are
gone, the header is not filed as a currency, honour is filed under the id the row carries -
`1792`, not under its name, which is what every other client has to infer from a link or from
the twelfth value of a row - and the amount and cap come back as the client gave them.

### What had to be fixed first, and it was not the client

The section could not be written at all to begin with: the scanner bound itself to `_G.Family`
rather than to the addon vararg, so loading it against a substitute Family did nothing. It
bound to the real addon and wrote to the real database while the checks read an empty recorder,
which looks exactly like a stub that does not work.

Three files in `addons/Family/` did this against 41 that take the vararg: `Scanners/Currencies.lua`,
`Scanners/Merchant.lua`, `Scanners/Pets.lua`. It is **not** a fault in the client: `Core.lua:13`
publishes the private table under that name, so they are the same table and the game never knew
the difference. It is a fault in what can be measured - and the three files it touches are the
merchant, the currencies and the pets, which is a third of what Midnight changes. Rebound, with
the reason written where the line is.

### And a fixture that let a mutation through

The first header in the new fixture was written from the head - a name, `isHeader`, an id - and
a mutation removing the `isHeader` guard survived, because a header with no `quantity` is thrown
out anyway. The client's own headers carry `quantity = 0` and `currencyID = 0` and look exactly
like a currency nobody has any of; `0` is truthy in Lua, so without that guard the list header
*Midnight* is filed under the key `c0`. The fixture now carries what the run read. L-209.

## 22. The bank Family already reads, and the tab it does not (2026-09-22)

Five checks on the fourth pretend client, with the container layout §6 measured.

**Family reads Midnight's six bank tabs today, and by accident.** `Scanners/Bank.lua` walks
`BANK_CONTAINER` - absent here, so it falls back to `-1` - and then the bags from
`NUM_BAG_SLOTS + 1` to that plus `NUM_BANKBAGSLOTS - 1`. With what this client answers, that
range is **5 to 11**, and §6 measured the character's six tabs at **6 to 11**. Nothing was
written for Midnight; the Classic bank-bag range happens to cover the Midnight tabs. It is
worth knowing which parts of the port are luck, because luck moves: if this client ever
answered five carried bag slots, the same arithmetic would reach container 12.

**Container 12 is not read, and today that is right.** It is the warband tab, the account owns
it rather than the character (decision of 2026-09-21), and the check says so in those terms
rather than recording a gap to close.

**Nothing is written for `-1` or for bag 5**, both of which this client answers zero slots for,
and a bank scan with no window open still writes nothing at all - L-019's guard, which the
section exercises first so that the four checks after it mean something.

One mutation: the bank window container falling back to the backpack instead of `-1`. It
**survived** the first time, because the fixture had no container 0 - the backpack is there on
the real client and was missing from the stub, which is L-209 within a day of writing it. With
the backpack in the fixture the mutation is caught, and the failure names it: *0,6,7,8,9,10,11*.

## 23. The reputations Family ships and Midnight cannot answer (2026-09-22)

Seven checks on the fourth pretend client. **This is the first slice that measures a gap rather
than a working route**, and nothing is fixed in it: the fix is step 3's and needs a reading this
file does not yet have.

**Family asks Midnight a question it cannot hear.** `Scanners/Character.lua` reads factions
through `GetNumFactions`, `GetFactionInfo`, `ExpandFactionHeader` and `CollapseFactionHeader`,
and the run of 2026-09-20 has all four as `nil` (`Ahia-Chamber of Aspects`, build 69875).
`UPDATE_FACTION` still registers, so the scan is still *asked for*, on a schedule, and finds
nothing every time. The client's answer is elsewhere and is not small:
`C_Reputation.GetNumFactions()` says **67**, and the namespace holds 27 functions.

**What that costs, measured by running the scanner rather than by reading it.**
`Character:ReadReputations()` answers an empty list and throws nothing - `Family:TryCall`
absorbs four absent globals without a word, which is the design working. `ScanNow` then guards
`#factions > 0`, so **no `reputations` key is written at all** rather than an empty one, and the
panel says *nothing has been recorded* instead of *no factions*. That part is right.

**And one part is not.** `reputationCount = factions and #factions or nil` hands `SetMeta` a
**zero**, because `#factions` is 0 and `0` is true in Lua. The summary is fed from meta and
nothing else, so on Midnight a character liked by sixty-seven factions is summarised as measured
and liked by none. It is checked here as it is, not as it ought to be: changing it belongs to the
commit that gives this client a route, and a check that pins today's wrong answer is what will
make that commit notice it.

### The rest of the character scan, added 2026-09-22 after §26

The fixture first written for this section absented the four faction globals and left the rest
to the base client - so a Midnight scan read a spellbook out of a client that has none. Nothing
checked here depended on it and it was still a fixture going past its client, which is §26's
lesson turned on this section. **All six spellbook globals are absent in the run** and are absent
in the stub now: `GetNumSpellTabs`, `GetSpellTabInfo`, `GetSpellBookItemInfo`,
`GetSpellBookItemName`, `GetSpellInfo`, `GetSpellSubtext`. `GetSpellInfo` is the widest-reaching
absence in the whole file.

Three readings came out of it, and the file is two thirds broken on this client:

- **Equipment works.** `GetInventoryItemLink`, `GetInventoryItemID` and `GetItemInfo` all answer,
  and a whole scan records the worn gear and the item level. It is the only one of the three
  subjects in `Character.lua` that needs nothing.
- **No spellbook is recorded**, and rightly: `ReadSpells` leaves on a tab count of nought and
  answers nil, and `ScanNow` writes the key only if it got a book.
- **And what another client read is left alone.** `specialisations = book and (branches or
  Family.CLEAR) or nil` is nil when the book is nil, and `SetMeta` skips a nil field. Checked
  with two specialisations read elsewhere put on the record first: still there after a Midnight
  scan. This is exactly the case §26 found going the other way, and the difference between them
  is one `book and`.

**One mutation, and it is caught by this section alone.** Dropping the `#factions > 0` guard, so
that an empty list is filed as a reading, leaves **every check on all three Classic clients
green** - on those the list is never empty - and is named only by *and records no reputations at
all rather than an empty list*. Confirmed by applying it by hand and running the whole harness:
one failure, in the new section.

### Why the code step cannot start today

`GetFactionDataByIndex(1)` answers a table of **seventeen** keys and version 9 wrote down
**twelve** of them: `atWarWith`, `canSetInactive`, `canToggleAtWar`, `currentReactionThreshold`,
`currentStanding`, `description`, `factionID`, `hasBonusRepGain`, `isAccountWide`, `isChild`,
`isCollapsed`, `isHeader`. They sort alphabetically and the cut fell at `isHeader`, so a
faction's name was among the five nobody had seen - L-201 for the third time, the same cut that
once hid a currency's name.

**Answered on 2026-09-22 by the version 14 run, and this paragraph is kept as it stood** because
what it could not see is the point. The five were `isHeaderWithRep`, `isWatched`, `name`,
`nextReactionThreshold` and `reaction`: the name, the standing and the bar - the whole of what a
reputation is. §27 has the rows; the fixture here now carries all seventeen.

### The one field that is already an answer to something else

`isAccountWide` is on the faction record itself, beside `isChild`. The account-versus-character
question - §13's second shape question, decided 2026-09-21 in favour of a second kind of record
(`DECISIONS.md`, that date) - is therefore answerable **per faction and by the client**, rather
than settled once for the domain by us. What is read is only that the field exists: the one row
written down answers `false`, and no row answering `true` has been seen, so *some of the 67
belong to the account* is a deduction and not a measurement. Version 14's index 2 is the cheapest
place to start turning it into one. What is already decided is that the code step reads that
flag rather than deciding the matter for reputations in general.

## 24. The quest log, and the same question answered the other way (2026-09-22)

Six checks on the fourth pretend client, and they are here to be read beside §23.

**Measured 2026-09-20**: `GetNumQuestLogEntries`, `GetQuestLogTitle` and `SelectQuestLogEntry`
are `nil`, while `ExpandQuestHeader`, `CollapseQuestHeader`, `GetQuestLink`,
`GetNumQuestLeaderBoards`, `GetQuestLogLeaderBoard` and `GetQuestObjectiveInfo` all answer. So
the scanner has most of its calls and not the one it starts with.

**And it stops, which is right.** `Scanners/Quests.lua` opens `ScanNow` with a test of
`GetNumQuestLogEntries`, leaves if it is not a function, and says *no quest log on this client*.
Nothing is written: no payload, and **no `questCount` in the summary**. The comment further down
gives §2.2's reason in its own words - an empty log and a log that could not be read are
different answers. Driven on the fourth client, all of that holds: the walk never starts and not
one heading is opened.

**Which is exactly what the reputation scanner does not do.** Same client, same class of
absence, and `Character.lua` writes `reputationCount = 0` (§23). Two scanners, one question,
two answers, and the quest one is the shape the port keeps. The mutation here makes the guard
never fire, and the failure prints `questCount 0` - the reputation fault, reproduced on demand
in the scanner that does not have it. **Every check on all three Classic clients stays green**
under it, which is why this section had to exist for anybody to notice.

### The gap is one call wide

`C_QuestLog` on Midnight holds **90 functions**, and `GetNumQuestLogEntries` is among them,
beside `GetInfo`, `GetTitleForLogIndex` and `GetQuestIDForLogIndex`. `Quests.lua` **already calls
that namespace twice** - `GetQuestIDForLogIndex` for the id and `GetNumQuestObjectives` for the
objectives - and both live inside the walk, so on this client neither is ever reached. The port
for quests is not a new scanner. It is the count and the title row, and the rest of the file
already knows where it is.

### And the third time the instrument was the thing in the way

`C_QuestLog.GetInfo(1)` answers **26** keys and version 9 wrote **12**, from `campaignID` to
`isOnMap` - so `title` and `questID` were past the cut, exactly as a faction's name was (§23) and
a currency's before it (L-201). Three for three, and a fourth turned up the same day (§25).
Version 14 answered all of them; §27 has the rows. The keys are sorted and a record's flags are called
`is…`, `has…`, `can…`, `at…` while what names the thing is called `name`, `title`, `questID`: an
alphabetical cut drops the identity every time. **`KEYS` is thirty from version 14**, read off
the run - the widest record-shaped answers Midnight gives are 28 and 29 keys, and everything
wider (157, 169, 261, 639) is a list. Written up as **L-210**, with the selftest check that was
missing: the currency one beside it passes on a call that asks for thirty by name, so it could
never have caught this.

## 25. The talent call that swaps the id and the name, put to the reader (2026-09-22)

Nine checks on the fourth pretend client. §16 calls `GetTalentInfo` the sharpest thing either
brief turned up and says Family survives it "by a habit it learnt the hard way" - **checked by
reading the code**, in that section's own words. This one runs it.

| | `GetTalentInfo(1, 1)` answers |
|---|---|
| Midnight | `22337 \| "Master Poisoner" \| 132108 \| false \| false \| 196864 \| false \| 1 \| 1 \| false \| nil` |
| Mists | `"Feline Swiftness" \| 538517 \| 1 \| 1 \| 1 \| 1 \| false \| 1 \| false \| false \| false \| 18569` |

Both are the run's own lines, and the second Midnight character gives the same shape with
different values (`22363 \| "Predator"`). The id and the name are on opposite ends.

**What the scan does, measured.** The capability table has no column 12, so `talentTrees` is
false and the tree reader is not the one asked - which matters more than it looks, because
`readTrees` **does** unpack `GetTalentInfo` by position (`name, icon, tier, column, rank`) and
would have written `22337` into a name field. It is not reached on this client because
`GetNumTalentTabs` is absent. So the habit is real in `interpret` and is **not** in `readTrees`,
and what protects Midnight is the capability answer plus an absent global, not the habit alone.

The record comes back as `system = "choices"`, tier 1 column 1 named *Master Poisoner*, read
through `C_SpecializationInfo.GetTalentInfo{tier, column, groupIndex}` - the reader that answers
a table, which is tried first and wins here; the loose call is never asked for a reading. Then
the same client with that namespace taken away, which is not this client and is worth a check
anyway, because it is the only way to put the swapped answer itself in front of the reader:
**the name is still the name and the id is still 22337**. That is `interpret` inspecting the
returns rather than unpacking them, and it is now measured rather than read.

### And the id the namespace route was said not to get - which was wrong

This section first reported that on the table route Family records the talent with **no id at
all**, because `interpret` takes one from `talentID` or `id` and neither was among the twelve
keys the run had written down of eighteen. The fixture carried the twelve and no more (L-209),
so the check pinned an absence.

**The version 14 run answers `talentID = 22363`, beside `spellID = 202021`.** It was the
seventeenth of eighteen sorted keys, and the old cut hid it. The reader had been right the whole
time and the finding was about the instrument, not about the game.

So L-210 did not only block two code steps and cost a field. Here it produced **a wrong
conclusion about this client, written into this file and into a check**, and the check that
carried it was green. That is the sharpest reason a limit on what a tool writes down is not a
matter of tidiness: a probe that shortens its answers does not report less, it reports something
else, and the something else reads exactly like a finding.

### What the two mutations here do and do not prove

`Scanners/Talents.lua` had **no recorded mutation at all** before today; it has two now. Dropping
the table-answering reader, and taking a talent's name from the first return instead of looking
for it, are both caught - but unlike §23 and §24, **neither is caught by this section alone**:
the Mists checks notice them too. The value of this section is not new coverage against those
two. It is that §16's claim was a code-read and is now a reading.

## 26. The 639 recipes Family reads and throws away (2026-09-22)

Seven checks on the fourth pretend client, and the largest gap of the four so far.

**Every old route is gone**: the skill sheet (`GetNumSkillLines`, `GetSkillLineInfo`,
`ExpandSkillHeader`, `CollapseSkillHeader`), the trade skill window (`GetNumTradeSkills`,
`GetTradeSkillInfo`, `GetTradeSkillLine`) and the craft window, all three. What answers is
`C_TradeSkillUI`, and it answers well: with an engineering window open on `Ahia`,
`GetAllRecipeIDs()` gives **639** ids, `GetRecipeInfo(1260349)` gives a table of **28** keys, and
`GetBaseProfessionInfo()` gives `professionName = "Engineering"`, `professionID = 202`,
`skillLevel = 305` of `805`.

**And `C_TradeSkillUI.GetTradeSkillLine` is absent**, which is the only call
`readModernRecipes` has ever used to name a profession. So Family walks all 639 ids, asks about
every one, keeps the ones marked `learned` - and hands back a list with no name. `ReadRecipes`
answers `nil` to a nameless list, which is right, and which here costs the entire read. Measured
rather than argued: the recipes were all looked up, and the answer is nothing.

**The gap is one call wide again**, as it was for quests. The name is in
`GetBaseProfessionInfo`, one call along in the same namespace, beside the id and the rank - and
an id is what the top of `Professions.lua` says a profession has never had on Era, which is why
it is keyed by a name there. So this client offers the shape the file has always wanted.

### What the scan writes, which is not nothing

The check that was written as *records nothing* went red, and the red was the finding.

- **An empty `professions` table is written** to the payload. Third time this branch has found a
  scanner recording a measured emptiness where it could not ask - `reputationCount = 0` (§23) and
  `questCount` are the other two, and only the quest one is guarded.
- **And the summary's `skills` are replaced with an empty table.** `SetMeta` merges field by
  field, so a field written empty *overwrites*, and `skills` is built from `ReadRanks`, which on
  this client can read nothing at all. Checked with a record made on another client put there
  first: two professions with ranks, read on Mists, **gone** after one Midnight scan with a
  window open. The payload's professions survive, because `ScanNow` starts from what was stored;
  the summary's do not.

That last one is the first thing this branch has found that **destroys** a record rather than
failing to add one.

**Repaired 2026-09-22, the same day.** `ReadRanks` now answers a third value saying whether
**anything answered at all** - `readSkillList` hands back its row count, and the third value is
`(modern ~= nil) or (rows > 0)` - and `skills` and `skillsLocale` are written only where it did.
Not a test of whether a function exists: the reading itself says whether it happened.

The line the guard has to fall on is not *was the answer empty*. A player really can unlearn
their last profession, and that is a reading that must be written, as an empty table, or the
panel goes on showing a trade nobody has. So a sheet that answers fifteen rows with no profession
among them still writes an empty summary; a client with no sheet and no `GetProfessions` writes
nothing. Two mutations, one on each side of that line, and the second is caught on **Era** rather
than here - which is the point of it.

Not in the changelog. The defect cannot fire on the three released clients, where the sheet
always answers: `GetNumSkillLines` gives fifteen rows on Mists, riding and weapons among them,
and Era and Burning Crusade have languages besides. It becomes a changelog entry the day it is
measured firing on one of them.

### One mutation, caught by this section alone

Recording a nameless list instead of dropping it - `if not name then return nil end` made into
`name = "a profession"` - leaves every check on all three Classic clients green, where a
profession always has a name, and goes red three times here.

### And a fixture that lied four hundred lines away

`ExpandSkillHeader` and `CollapseSkillHeader` are measured absent and were left out of the stub
because the section is about recipes. The base client's versions answered instead, the skill list
was expanded with nothing recorded as collapsed, and *and the skill window is put back as it was
found* failed in a section further down. **L-209 with a longer arm**: an incomplete fixture does
not only weaken its own checks, it can break somebody else's.

## 27. What version 14 answered, and the three records the old cut had hidden (2026-09-22)

The run: **Midnight 12.1.0, build 69875, interface 120100**, `Druiduga-Chamber of Aspects` with
`Ahia` and `Mara` beside her in the same file. Asked for on the strength of §23 to §26, taken at
login, with no window opened and no fight - the three answers below are all login reads, and all
three were **already taken on 2026-09-20 and thrown away by the probe's twelve-key cut** (L-210).

Older runs sit in the same file and the truncated lines are still there beside the full ones.
`--report` says which run it read (L-206); the rows below are the version 14 ones.

### A faction

```
C_Reputation.GetFactionDataByIndex(1) -> {#17
  atWarWith=false, canSetInactive=false, canToggleAtWar=false, currentReactionThreshold=0,
  currentStanding=0, description="", factionID=2569, hasBonusRepGain=false,
  isAccountWide=false, isChild=false, isCollapsed=true, isHeader=true,
  isHeaderWithRep=false, isWatched=false, name="The War Within",
  nextReactionThreshold=3000, reaction=4 }
```

Index 2 is `factionID=2506`, `name="Dragonflight"`, the same shape. **Both are headers**, so an
ordinary faction's row is still unseen - but the key *set* is the answer that was wanted, and it
maps onto `Character.lua` line for line:

| the old call's return | the modern key |
|---|---|
| `name` | `name` |
| `factionID` | `factionID` |
| `standing` | `reaction` |
| `barMin`, `barValue`, `barMax` | `currentReactionThreshold`, `currentStanding`, `nextReactionThreshold` |
| `isHeader`, `isCollapsed` | `isHeader`, `isCollapsed` |
| `hasRep` | **`isHeaderWithRep`** |

That last row is the one worth having in writing. `hasRep` is the flag `ReadReputations` reads as
*a header that itself has a standing*, and the note in the code says getting it backwards once
emptied the panel on a fully played character. The modern name says what it means.

`isAccountWide` is there and answers `false` on both, so the per-faction account question (§23)
is still a deduction: the field exists, and no row answering `true` has been seen.

### A quest

```
C_QuestLog.GetInfo(1) -> {#26
  campaignID=256, difficultyLevel=0, hasLocalPOI=false, headerSortKey=-2147483392,
  isAbandonOnDisable=false, isAutoComplete=false, isBounty=false, isCollapsed=false,
  isHeader=true, isHidden=false, isInternalOnly=false, isOnMap=false, isScaling=false,
  isStory=false, isTask=false, level=0, overridesSortOrder=false, questClassification=2,
  questID=0, questLogIndex=1, readyForTranslation=false, sortAsNormalQuest=false,
  startEvent=false, suggestedGroup=0, title="Dragonflight", useMinimalHeader=false }
```

Row 1 is a heading again - `isHeader=true`, `questID=0` - which is what a quest log's first row
is. What `interpretTitle` needs is all here and under plain names: `title`, `level`, `isHeader`,
`isCollapsed`, and `questID` where the old call hid the id somewhere among its returns and
`questIDAt` had to go looking for it by asking `GetQuestLink` about each candidate. **The modern
call makes that search unnecessary**, which is a simplification the port gets for free.

### A talent

```
C_SpecializationInfo.GetTalentInfo{tier=1, column=1, groupIndex=1, isInspect=false} -> {#18
  available=false, column=1, grantedByAura=false, hasGoldBorder=false, icon=132167,
  isExceptional=false, isPVPTalentUnlocked=false, known=false, maxRank=1, meetsPrereq=false,
  meetsPreviewPrereq=false, name="Predator", previewRank=1, rank=1, selected=false,
  spellID=202021, talentID=22363, tier=1 }
```

`talentID`, `spellID`, `selected` and `rank` were all past the old cut. §25 had reported the id
as missing from the client; it was missing from the probe. The four checks in that section are
corrected and the fixture carries all eighteen keys.

### What this unblocks, and what it does not

| Domain | State |
|---|---|
| Reputations (§23) | **unblocked.** Every field `ReadReputations` writes has a named source |
| Quests (§24) | **unblocked**, and the id search can go |
| Talents (§25) | **was never blocked**, and this file said it was |
| Professions (§26) | never blocked - `GetBaseProfessionInfo` was read whole on 2026-09-20 |

Still unseen, and neither is in the way: an **ordinary faction** row and an **ordinary quest**
row. Both index-1 reads landed on a heading. A `GetFactionDataByIndex(n)` at a higher index and a
`GetInfo(n)` beside it would settle the shape of a row that is not a heading, and both are one
line in version 15 if any later slice turns out to want them.

## 28. The merchant, which is the dangerous shape and survives it (2026-09-22)

Five checks on the fourth pretend client, and the first domain of the four where what the client
answers is **partial** rather than absent.

**Measured 2026-09-20 at a vendor**: `GetMerchantItemInfo` is absent, while
`GetMerchantNumItems`, `GetMerchantItemLink` and `GetMerchantItemCostInfo` all answer. So the
window is not silent. It says how many rows it has and hands back a link for every one - and the
single call that is gone is the one carrying the **price** and the **stack size**. A reader that
took the count as proof the window could be read would file every item at no price at all, and
`Merchant:Read()` keeps the *highest* figure ever seen for an item precisely so that a later
sighting can only improve the record - so a zero written once could never be improved away.

**It writes nothing, and the guard that saves it was written for something else.** §2.2's rule -
say nothing rather than round something into the record - asks for a price and a quantity both
present and positive, and for the one to divide exactly by the other, before a figure is kept.
On this client the price is nil and the whole row falls at the first clause. The rule was written
about stacks that do not divide; it happens to be exactly the rule a client missing the call
needs. Worth recording as luck, in the way §22's bank range was: nobody chose it.

### What would answer it, measured at the same vendor

```
C_MerchantFrame.GetItemInfo(1) -> {#9
  hasExtendedCost=false, isPurchasable=true, isQuestStartItem=false, isUsable=true,
  name="Tough Hunk of Bread", numAvailable=-1, price=20, stackCount=5, texture=133964 }
```

`price` and `stackCount` are the two that went missing, and **`hasExtendedCost` is a third thing
for free**: `Read` asks `GetMerchantItemCostInfo` in a separate call to find out whether a row is
bought with badges or marks rather than money, because recording the money half of an extended
cost puts a few silver against an epic. The modern answer says it in a field. So the port here is
one call that replaces two.

A second run of the same call answered **eight** keys with `name` absent, a moment before the
item had loaded. Nothing reads `name` here - a price is filed by id (§2.1) - but it is the shape
of answer this file has been bitten by before, and it is written down.

### And the rest of `C_MerchantFrame`

Seven functions: `GetBuybackItemID`, `GetItemInfo`, `GetMerchantCurrencies`, `GetNumJunkItems`,
`IsMerchantItemRefundable`, `IsSellAllJunkEnabled`, `SellAllJunkItems`. `GetMerchantCurrencies(1)`
answered an empty table and `GetNumJunkItems(1)` answered 0 at that vendor. Nothing here needs
them; they are written down so that the next reader of this section does not ask again.

### One mutation, caught by this section alone

Defaulting a missing price to nought and a missing stack to one - which is what a reader written
from the count would do - files the bread as free. Every check on all three Classic clients stays
green, because there the call answers.

## 29. Pets, and the four shapes step 2 has now measured (2026-09-22)

Three checks, and they close step 2's sweep of the scanners.

**Measured 2026-09-20**: `HasPetSpells`, `GetPetTrainingPoints` and `GetStablePetInfo` are all
`nil`, while `UnitCreatureFamily`, `UnitGUID` and `UnitLevel` answer and the stable events
register. So the scan is still asked for and every reading it depends on is gone: no stable, and
no book for whatever creature is out.

**And nothing is written, on purpose.** `Pets:Scan` ends on
`if not stable and not out then return end`, and the comment over that line says why in terms
this branch did not have to invent: *nothing read at all leaves the record alone rather than
writing an empty one ... it is also every scan a mage ever runs, which is the common case and
must not touch the record at all.* On Midnight every character is that mage. The guard written
for the common case is the one that stops a Midnight login rewriting a hunter's pets, checked
here with a hunter's record - a stabled cat and a known creature - put on the file first and read
back unchanged, `seen` included.

The mutation that disables the guard is caught here **and by an existing check**, so unlike §26
and §28 this section is a second witness rather than new coverage. What it adds is the reading
that the guard is load-bearing on a whole client and not only on a class.

### The four shapes, which is what step 2 was for

| Scanner | On a client it cannot read | |
|---|---|---|
| Quests (§24) | writes nothing, guarded at the top by the call it needs | right |
| Pets (§29) | writes nothing, guarded at the bottom by what the reading produced | right |
| Reputations (§23) | writes `reputationCount = 0` | wrong, and open |
| Professions (§26) | wrote `{}` over a summary made elsewhere | wrong, and repaired 2026-09-22 |
| Merchant (§28) | writes nothing, by a guard written about arithmetic | right, by luck |

Two of the five guard themselves deliberately, one by luck, and two did not. **The one common
factor in the two that did not is that they write a count or a table unconditionally after a
read that can fail**, and the one common factor in the three that hold is that something in the
write path asks what the reading actually produced. That is the rule the code step carries into
every scanner it touches, and it is worth more than any single fix: `reputationCount` is the last
one outstanding, and it is one line.

### What nobody has ever asked

The census counts **`C_StableInfo` at 14 functions and `C_PetInfo` at 7**, and no run has ever
listed what is in either. They are version 15's, added to the namespaces the probe names on every
client - listed and not called, because a stable call takes a slot index this repository has not
measured and naming one would be guessing (L-200). They come from a measurement rather than from
a brief, which makes them the first entries in that table that do.

## 30. The auction house, which needs nothing, and a stub that reproduced L-068 (2026-09-22)

Seven checks, and the first domain of the six that works end to end on this client.

**Measured 2026-09-20**: the old house is gone - `GetNumAuctionItems`, `GetAuctionItemInfo`,
`GetAuctionItemLink`, `GetAuctionItemTimeLeft`, `GetOwnerAuctionItems`, `CanSendAuctionQuery` -
and `C_AuctionHouse` holds **every member Family names bar `GetAuctionHouseDepositRate`**, which
nothing outside a diagnostic in `Family_UI/Slash.lua` reads. The events split:
`AUCTION_ITEM_LIST_UPDATE`, `AUCTION_OWNED_LIST_UPDATE` and `AUCTION_BIDDER_LIST_UPDATE` are
refused; `AUCTION_HOUSE_SHOW`, `AUCTION_HOUSE_CLOSED`, `OWNED_AUCTIONS_UPDATED`,
`REPLICATE_ITEM_LIST_UPDATE` and the browse pair register.

**And the events are why it works.** `Auctions:Scan` is driven by a loop over three names, two
of which this client refuses - and the third is `OWNED_AUCTIONS_UPDATED`, in the same loop,
written for a house nobody here had seen. An event a client does not have registers as nothing
at all (§2.2), so the loop needs no branch and has none. Driven end to end here: opening the
window queries the modern house, the modern event answers, the scan reads
`C_AuctionHouse.GetNumOwnedAuctions` and files none selling.

**What is not measured**: the shape of a Midnight owned-auction row. `GetNumOwnedAuctions()`
answered **0** in the run, because that character had nothing up, so the fixture answers 0 too
rather than borrowing the row `main` measured on Mists on 2026-09-10. A `main` measurement is
the question here and never the answer. One auction posted before the next run settles it.

### The stub was wrong in the way the code documents

The first version of the section's `RegisterEvent` kept **one handler per event name**, and it
threw half the file away without a word. `AUCTION_HOUSE_SHOW` and `OWNED_AUCTIONS_UPDATED` are
each registered **twice** - once to do the work, once under the key `auctions.heard` to count
that the event arrived, which is what the visit rule rests on. Keyed by name alone, the counter
replaced the worker, opening the house asked for nothing, and the check that should have caught
it reported `nil`.

That is **L-068**, and it is not an analogy: `Core.lua:60` says *a second registration under one
key replaces the first, in silence*, and `Scanners/Auctions.lua:2610` records that this exact
pair of events did exactly this in the game on 2026-09-10 - opening the window stopped asking for
the character's own listings, and the panel read *not seen* for everybody with nothing in the log
to say why. **A stub that models a registry loosely reproduces the bug the registry was fixed
for**, and it reproduces it silently, because a stub has no user to complain.

The mutation recorded here is that bug, written out: register the counters under `auctions`
rather than `auctions.heard`. It is caught five times over, on this client and on the Classic
ones, which is what a fault that once shipped ought to look like.

## 31. The mailbox, which needs nothing at all, and step 2 closes (2026-09-22)

Six checks, and the shortest finding in this file: **nothing is missing**.

`GetInboxNumItems`, `GetInboxHeaderInfo`, `GetInboxItem`, `GetInboxItemLink`,
`GetSendMailItem`, `GetSendMailItemLink`, `GetSendMailMoney` and `GetSendMailCOD` all answer, and
`MAIL_SHOW` and `MAIL_INBOX_UPDATE` both register. Every call and every event
`Scanners/Mail.lua` makes is on this client, which is why the second brief's *mail is almost
unchanged since the beginning* is the one claim in it that needed no qualification (§14).

So the only thing the fourth pretend client changes here is the **build**, and that is what the
section checks: the base client's mailbox fixture, unchanged, scanned with `GetBuildInfo`
answering 12.1.0 and the capability table holding no column for it. Both letters, the sender, the
money, the attachment by id and the count the letter claimed. **It adds no new mutation
coverage** - the base mail section already stands over this code - and that is said here rather
than dressed up: a domain that needs no port still has to be seen surviving the new client, and
that is the whole of what these six checks are worth.

### Two ways this section broke other sections before it worked

Both are the same fault as §26's fixture, wearing different clothes, and both are written up.

- **The proxy pattern does not fit a scanner that hooks a global.** Loading `Mail.lua` a second
  time against a substitute `Family` installed a **second** `hooksecurefunc` on the client's own
  send path, bound to the substitute. The mail section passed; four hundred lines later another
  section posted a letter, both hooks fired, and the proxy's died on a `Database:Members` the
  substitute never had. The run stopped with a traceback pointing at `Mail.lua:171`, which is not
  where anything is wrong. This section runs against the real `Family.Mail`. **L-212**.
- **A real scan on the real database leaves a record.** A section further down checks that
  nothing is recorded until a mailbox is opened, and it reads **meta**, so putting the payload
  back was not enough. Every field the scan writes is captured by name and restored, with
  `Family.CLEAR` where it had been nothing, since `SetMeta` skips a nil.

### Step 2 is finished

Seven scanners driven on the fourth pretend client, plus the client itself: bags (§18),
currencies (§21), bank (§22), reputations (§23), quests (§24), talents (§25), professions (§26),
merchant (§28), pets (§29), auctions (§30) and mail (§31). **The harness is 3683 checks**, from
3611 when step 2 began.

| Domain | On Midnight |
|---|---|
| Bags, bank, currencies, auctions, mail | work |
| Merchant | writes nothing, correctly, and by luck (§28) |
| Quests, pets | write nothing, correctly and deliberately |
| Reputations | write a zero; the route is unblocked and unwritten |
| Professions | read 639 recipes and drop them for want of a name; the erasure is repaired |
| Talents | work, and the file's claim about why was half wrong (§25) |

What step 3 inherits is three gaps each one call wide - `C_QuestLog.GetNumQuestLogEntries`,
`C_TradeSkillUI.GetBaseProfessionInfo`, `C_Reputation.GetFactionDataByIndex` - one line to stop
`reputationCount` reporting a zero, and the rule §29 names: **a count or a table written
unconditionally after a read that can fail is the whole of what went wrong in the two scanners
that got it wrong.**

## 32. The merge of 2026-09-22 evening, and one name the client has not been asked

Seventeen commits of `main` since the last merge, landing Backlog 96: a gathering node's tooltip
answers who in the family holds that herb or ore, on the world, the minimap and the world map.
It touches the client, so it was merged the same evening under the per-landing rule. One conflict,
in `DECISIONS.md`, where both sides had appended rows; both kept whole, this branch's first.
`LESSONS.md` merged clean and carries no new duplicate number - only the deliberate L-103.

**`tools/surface.py --check` said the list had moved**, which is the rule doing its job for the
second time. The generator now finds **279** globals, and the one new name is `WorldMapFrame`,
read in `Family_UI/Tooltip.lua` to decide whether the frame under the cursor is drawn on a map.

It is read as `local maps = { _G.Minimap, _G.WorldMapFrame }` and compared with
`if map and frame == map`, so a client without it skips it and nothing can break. **No run has ever
asked Midnight about it.** The regenerated `Surface.lua` travels with probe version 15, which asks
it at login with the other 278, so the next run answers it without anybody playing specially.

## 33. The merge that brought this branch's vararg back from `main` (2026-09-23)

`main` landed the two things it had decided and not yet done - checked with FAMILY DEV before
reading them as done, since from here only git is visible and git had neither:

- **`73debab`** takes the addon's own table in `Scanners/Currencies.lua`, `Merchant.lua` and
  `Pets.lua` - the change this branch made in `cf107f0` so that the fourth pretend client could
  drive them - with a harness check that reads the files and the mutation
  `a-scanner-reaches-for-the-global-family.mut`, **under the same name as this branch's**, so that
  the two copies read together. Backlog 100.
- **`0cd1f44`** prints a record whole in `tools/FamilyProbe`, cut at thirty with `WANTED` still
  first - L-210 carried to `main`'s probe - and tries it on the eighteen-key talent record this
  branch measured, `talentID` included. Backlog 101.

**The conflict was the predicted one and it was only words.** The code was identical on both
sides, `local _, Family = ...`; this branch had a seven-line comment above it and `main` has
none, and the two `.mut` files differed only in their `name:` line. The change is `main`'s now, so
`main`'s side was taken for all four files and they are byte-identical to `main`. The reason lives
in `DECISIONS.md` on both sides, which is where a reason for a one-line binding belongs.

Backlog 93 landed in the same merge - raid lockouts - and `surface.py --check` said the list had
moved for the third time: **282 globals and 139 literals**, from 279 and 137. Three of the five new
names Midnight has already answered, through the second brief's lockout block:
`GetNumSavedInstances()` answers 0, `GetSavedInstanceInfo(1)` answers fourteen values, and
`UPDATE_INSTANCE_INFO` registers. **`RequestRaidInfo` and `BOSS_KILL` have never been asked.**
The regenerated `Surface.lua` rides probe version 15, which asks both at login.

## 34. The merge of 4.4.0, and two more names the client has not been asked (2026-09-23)

`main` released 4.4.0 at `fe0b690` - thirty-three commits since §33 - and FAMILY DEV asked for it
to be read and merged. What it brings that calls the client:

- **Quests already handed in** (backlog 92), a new `Scanners/QuestHistory.lua`: `GetQuestsCompleted`
  handed a table to fill, on `PLAYER_ENTERING_WORLD` and `QUEST_TURNED_IN`. Where the global is
  not a function it returns nil and the scanner writes nothing and says *no quest history on this
  client* - the same silence as the quest log and the pets on this client, not a zero.
- **Rested experience worked forward** (backlog 94), in `Scanners/Identity.lua`: `IsResting` and
  `GetXPExhaustion`, both through `TryCall`.
- **A collapsing recipe list read twice** (backlog 68), in `Scanners/Professions.lua`: `GetTime`
  and a `Family:After` of two seconds. It sits in the recipe block; this branch's repair of §26
  sits in `ReadRanks` and the summary's `SetMeta`, and git joined the two without a conflict.
  On this client the recipe block is never reached while `GetTradeSkillLine` is absent (§24), so
  the hold has nothing to hold here yet.

**The one conflict was `DECISIONS.md`**, both sides appending rows on the same day; both were kept,
this branch's first.

`surface.py --check` said the list had moved for the fourth time: **284 globals**, from 282, the
literals unchanged at 139. The two new names are **`GetQuestsCompleted` and `IsResting`**, and
Midnight has been asked neither. The regenerated `Surface.lua` rides probe version 15 unchanged -
its surface pass says whether each is a function, which is the first half of the question.
The second half, for `GetQuestsCompleted`, is whether it still fills the table it is handed; that
is for a brief once the first half is known, and nothing here assumes the Retail answer.

The harness went from 3773 checks to 3846 with the three Classic stubs as `main` left them.

## 35. Probe version 15 on Midnight: Ahia, an auction up, and the quest history absent (2026-09-23)

One file came back holding three records, because runs accumulate: **Ahia**, a level-50 rogue,
enUS, **build 69933** - the version-15 run - beside Druiduga and Mara from earlier runs on
69875. Ahia's is the only record holding the six names added to the list since, which is how it
is told apart; nothing else in the file says which probe version wrote it.

**The client did not move under the build number.** Ahia's globals block holds 286 entries and
Druiduga's 280; sorted and compared, the difference is exactly the six new names, and every name
the two share answers the same. The literals refused are the same 75 on both.

| Name | On Midnight | So |
|---|---|---|
| `GetQuestsCompleted` | **absent** | `QuestHistory:Read` returns nil and the scanner writes nothing - a silence, not a zero (§34) |
| `IsResting` | function | the rested estimate has both its reads (`GetXPExhaustion` was already known) |
| `RequestRaidInfo` | function | the lockout scanner's request is there |
| `BOSS_KILL` | registers | |
| `GetNumSavedInstances`, `GetSavedInstanceInfo` | function; 0 saved, and index 1 answers the fourteen-value shape empty | as §33 records |
| `WorldMapFrame` | table | |

`C_QuestLog`'s own listing holds **`GetAllCompletedQuestIDs`** and
**`IsQuestFlaggedCompletedOnAccount`**. Their names are measured and their answers are not: no
call was made. That is the route for the quest history here, and it goes onto step 3's list as
the fifth gap; what it returns is for a brief call before any code.

`C_StableInfo` lists fourteen functions, `GetActivePetList`, `GetStabledPetList` and
`GetStablePetInfo` among them, and `C_PetInfo` seven. Listed, not called, and on a rogue there
would be nothing to call them about: the pets route needs a hunter.

### The owned auction row

`C_AuctionHouse.GetNumOwnedAuctions()` answered 1 and `GetOwnedAuctionInfo(1)` answered
**six keys: `auctionID`, `buyoutAmount`, `itemKey`, `quantity`, `status`, `timeLeftSeconds`**.
The probe cuts at thirty, so that is the whole row. **No `itemLink`, no `bidAmount`, no
`minBid`** - the same six `main` read on Mists 2026-09-10, which `readModernOwned` was written
for and cites (`Scanners/Auctions.lua:136`). So §30's *needs nothing* now rests on a row and not
on a zero.

The harness section of §30 keeps its zero reading and adds this row after it: one entry
selling, id, count, buyout, no bid, no item string, and the expiry exact to the second. **What
is still not measured is inside `itemKey`** - the probe prints a nested table as `table` - so the
`itemID` there is the harness's and is labelled so. If Midnight's `itemKey` held no `itemID` the
row would be dropped in silence; the next probe version should print it one level down.

The mutation `a-midnight-owned-row-needs-a-link.mut` (a row recorded only where it carries a
link) is caught by the three new checks **and by `main`'s Mists-shape checks** in the base
auction section, since the two rows have the same shape. The new checks add the Midnight reading;
they do not add coverage the code lacked.

### Also in the record, unchanged

Mail answered one letter whole; the merchant, both at once and two seconds on, as §28; the bank
sweep as §22; the thirteen combat reads answered in combat what they answered outside it;
`C_Reputation.GetNumFactions()` 67, and index 2, *The Cartels of Undermine*, carries
`isAccountWide = true` and `isHeaderWithRep = true`.

### Step 3's list, now five

`reputationCount`'s zero; the quest log through `C_QuestLog.GetNumQuestLogEntries`/`GetInfo`; the
profession's name through `C_TradeSkillUI.GetBaseProfessionInfo`; reputations through
`C_Reputation.GetFactionDataByIndex`; and **the quest history through
`C_QuestLog.GetAllCompletedQuestIDs`**, once its answer has been read.

## 36. Step 3 (a): a faction list nobody could read is no longer a list of none (2026-09-23)

The first of step 3's five, and the one §23 pinned wrong on purpose. `Character:ReadReputations`
began with `local count = Family:TryCall(GetNumFactions) or 0`, so a client with no
`GetNumFactions` came out as an empty list, and `ScanNow` wrote `reputationCount = #factions` from
it: **0**, because 0 is true in Lua. The summary reads meta and nothing else, so on Midnight a
character read as belonging to no faction, when nobody had read them at all.

Now the count is kept as the client gave it, and **the read answers nil where the count is nil**,
an empty list only where the count answered nought. The loop that puts collapsed headers back
still runs either way; the answer is decided at the end and not by an early return. `ScanNow`
already skips a nil (`reputationCount = factions and #factions or nil`, and `SetMeta` skips a nil
field), so it needed no change. The one other caller, the timing diagnostic at
`Family_UI/Slash.lua:2376`, already reads `factions and #factions or 0`.

This is §29's rule again and the same fault §26 repaired in the skill summary: **a count written
after a read that can fail has to know whether the read happened.**

The harness section of §23 turns round. The read answers nil; a count answering nought still
answers an empty list; and a `reputationCount` of twelve left by an earlier reading survives the
Midnight scan, the way the specialisations do.

**One case from step 2 stopped testing anything, and was kept by a new check rather than
dropped.** `an-empty-reputation-list-is-recorded-as-a-reading.mut` removes the `#factions > 0` in
`if factions and #factions > 0 then payload.reputations = factions end`, and the Midnight scan was
what caught it; with the read now nil there, it survived. The guard still means something - on
any client, a count of nought does not replace a list already stored - and it has been in the file
since the first commit with no reason given, so it is not this branch's to change. The section now
drives that case directly, and the mutation's name says what it tests now. Two new cases:
`an-unreadable-faction-list-is-read-as-none.mut` (the old answer back) and
`a-faction-count-of-nought-is-read-as-a-silence.mut` (the correction overdone). Harness 3850.

Nothing is read from `C_Reputation` yet; that is (d).

## 37. Step 3 (b): the quest log read through `C_QuestLog` (2026-09-23)

The second of step 3's five. `Scanners/Quests.lua` now counts and reads the log by whichever route
the client answers, and on Midnight that is `C_QuestLog.GetNumQuestLogEntries` and
`C_QuestLog.GetInfo`.

- **`countEntries`** asks the old global first and `C_QuestLog`'s count only where the old one
  answers nothing, and says which answered. Where neither does, the scan leaves as before and says
  *no quest log on this client*: the silence of §24 is kept, and it is now decided by asking the
  count and not by looking the function up.
- **`rowAt`** reads one row by the route the count came from. The old route is exactly the code it
  was - `interpretTitle` on the packed returns, `isCollapsed` on those returns. The new route is
  **`interpretInfo`**, which takes `title`, `level`, `isHeader`, `isCollapsed` and `questID` by
  name from the row §27 measured.
- **The id needs no search.** A newer row names its `questID`, so `questIDAt` - which hands
  `GetQuestLink` each candidate return and reads the title back - is used only where the row gave
  none. That is §27's *simplification the port gets for free*.
- **A hidden row is left out.** `isHidden` is a measured key; what it means is read from its name,
  and that is a decision and not a measurement.
- The headings are opened with `ExpandQuestHeader(0)` and shut again by index with
  `CollapseQuestHeader`, as on the other clients: both answer on Midnight (§24).

**Why this is a route in the scanner and not an entry in `Capabilities.lua`.** CLAUDE.md asks that
anything Retail has and Classic does not be data in the table and not a branch in a scanner. The
table records what the **game** has - guild banks, achievements, weapon skills - and every client
has a quest log. Which call reads it is a fact about the **build**, and the file's own thesis is
that the build's surface decides nothing about the game. So the route is chosen the way
`Scanners/Auctions.lua` chooses its own - both routes, neither looked up, each silent where it does
not apply - and by asking with `TryCall`, never `if fn then`. **The old count goes first**, so the
three Classic clients read by the route they were measured on even if one of their builds carries
the namespace too; a check says so, because no Classic stub has both and the order was otherwise
untested (its mutation survived until the check was written).

### What the fixture is made of

Row 1 is Druiduga's measured heading, all twenty-six keys. **Rows 2 to 5 are the harness's** - an
ordinary quest, a heading that starts shut, a quest under it and a hidden task - built on the same
keys, because none of them has been read on Midnight. So three things are still the game's to
confirm, in the smoke row and not here:

1. that an ordinary quest row carries the keys a heading does;
2. what `C_QuestLog.GetNumQuestLogEntries` returns after its first value, which is the only one
   read;
3. that `ExpandQuestHeader(0)` opens every heading on this client as it does on the others.

**Objectives are not driven.** `progressOf` is unchanged: `GetNumQuestLeaderBoards` by index, then
`C_QuestLog.GetNumQuestObjectives` and `GetQuestObjectiveInfo` by id. All three answer on Midnight
(§24); the fixture answers nought, and how far through a Midnight quest is will be seen in the game.

The section of §24 keeps its silence as its first half, with the newer count taken away as well,
and adds the log read the newer way: 13 checks, from 6. Mutations: the step-2 guard case moved to
the new guard, and five new ones - the newer count never asked, a hidden row recorded, the row's id
ignored for the search, headings put back by the old reader, and the newer count asked first.
Harness 3857.

## 38. Step 3 (c): a Midnight profession has a name again (2026-09-23)

The third of step 3's five, and the largest loss §26 found: 639 recipes read and dropped for want
of a name. `readModernRecipes` now asks `C_TradeSkillUI.GetTradeSkillLine` as before, and where
that gives no word asks **`GetBaseProfessionInfo()`** and takes its `professionName` - measured
with Ahia's engineering window open, *Engineering*, beside `professionID` 202 (§12, §26).

**An empty word is not a name.** With the window shut the same call answers the same fields
zeroed, `professionName = ""`, and taking that would file recipes under nothing; so only a
non-empty string is used. Mists answers the first call, so it never reaches the second and reads
exactly as it did.

Driven on the fourth pretend client with the recipe rows §26 used (one measured, one learned and
labelled as the harness's): the read now answers *Engineering* and the one learned recipe, the
scan records it **under 202** - `Family:SkillLineFor` turns the name into the skill line, as on
the other clients - and the window's reopening word is *Engineering*. The zeroed answer names
nothing. The two §26 checks that pinned the loss are turned round, and its repair's checks - the
summary's skills from another client left alone, no locale stamp moved - pass unchanged.

**Not done here, and on purpose.** `GetBaseProfessionInfo` also answers the id, 202, which is the
key Family has always wanted and had to derive from a word; this reads only the name and lets the
existing derivation give the same id. The child lines of §12 - one per expansion, each with its own
rank - are not read, and the one-rank-per-profession model stays as it is. Whether casting
*Engineering* opens the window on this client is the smoke row's question.

Two mutations - the second call never made, and the empty name taken - and the step-2 case
`a-nameless-recipe-list-is-recorded-anyway.mut` is still caught, now by the shut-window check.
Harness 3858.

## 39. Step 3 (d): reputations read through `C_Reputation` (2026-09-23)

The fourth of step 3's five, and the domain step 2 found asking a question this client cannot hear.
`Character:ReadReputations` now works the way §37 made the quest log work:

- **`countFactions`** asks `GetNumFactions` first and `C_Reputation.GetNumFactions` only where the
  old one answers nothing. Neither answering is still nil - §36's silence, unchanged.
- **`factionAt`** reads a row by the route the count came from and hands back the old call's
  terms, so everything below it - the category carried down the list, the `not isHeader or hasRep`
  rule, the bar arithmetic - is the code it was. The newer row maps one for one: `reaction` is the
  standing, `currentReactionThreshold` and `nextReactionThreshold` the ends of the bar,
  `currentStanding` the place on it, **`isHeaderWithRep` the old `hasRep`**.
- **`expandAt` and `collapseAt`** open and shut headings through `C_Reputation` on that route.
  Midnight has neither global; both functions are listed in the namespace (§35).

**The mapping rests on two measured rows, and one of them tests it.** *The Cartels of Undermine*,
Ahia's index 2, is a heading with a standing of its own: `reaction` 5, `currentStanding` 3000
between thresholds 3000 and 9000. Read the old way that is Friendly, nought of six thousand, which
is where a character who has just reached Friendly stands - the thresholds are absolute, as the
old call's bar was, and not relative to the standing. That a heading like this is a faction and
*The War Within* above it is only a heading is exactly the `hasRep` rule, now fed by the newer
name.

### What the fixture is made of

Three rows are measured: Druiduga's two headings, both shut, and Ahia's Cartels, all seventeen
keys each. **Two ordinary faction rows are the harness's** - no ordinary faction has been read on
Midnight - built on the same keys. The list opens and shuts as the client's does, so the section
checks that both shut headings were opened, that everything under them was found and filed under
the right heading, and that both were shut again, last first.

Checked beside it: neither count answers nil and asks for no row; where both counts answer the old
one is read and the newer is not asked (no Classic stub carries both, so this is the check that
holds the three Classic clients on their route); and a whole scan records the three factions and
tells the summary three over the twelve left by an earlier reading.

### Not done, and written down so it is not mistaken for done

- **`isAccountWide` is not recorded.** The Cartels answer `true`, so the field is live on this
  client, and a family view that shows the same account-wide standing on every character is a
  display question. Nothing stored changes shape in this slice.
- **Renown, paragon and the major factions are not read.** `C_MajorFactions` lists 29 ids and the
  Cartels are one of them (§35); their standing is read here as the row gives it and not as
  renown.
- **`AreLegacyReputationsShown`** exists, so the list may hide older factions behind a setting;
  what the list holds with it off is the game's to show.
- That `ExpandFactionHeader` and `CollapseFactionHeader` take the row's index, as the old ones did,
  is the smoke row's to confirm.

Six new mutations - the newer count never asked, `isHeaderWithRep` ignored, the bar measured from
nought, headings opened or shut through the old globals, and the newer count asked first - and
§36's three still caught. Harness 3865.

## 40. Probe version 16: what step 3 built on its own word (2026-09-23)

Step 3's four slices so far each left a line saying what the harness supplied because the client
had not been asked. Version 16 asks exactly those, and one more that step 3 cannot start without:

| Question | Asked how | For |
|---|---|---|
| an ordinary faction row | `C_Reputation.GetFactionDataByIndex` 3 and 4 | §39's two fixture rows |
| an ordinary quest row | `C_QuestLog.GetInfo` 2 and 3 | §37's fixture rows |
| the quest history | `C_QuestLog.GetAllCompletedQuestIDs()` | step 3 (e), not written until this is read |
| what an owned auction's `itemKey` holds | handed to `C_AuctionHouse.GetItemKeyInfo`, which prints it whole as its argument | §35: a Midnight row with no `itemID` in its key would be dropped in silence |

The first three are brief calls and run on Midnight only. None of them opens a window, queries
the server or changes the character; `GetItemKeyInfo` is a description of an item key and is
asked with the auction house open, where the key comes from.

The selftest has a claim for the fourth - an owned auction's key printed whole - and was seen to
fail with the call taken out. The README's count of claims said thirty-one; it was thirty-two
since L-210's claim on 2026-09-22 and is thirty-three now.

Not asked, because a probe cannot: whether `ExpandQuestHeader(0)` and `C_Reputation`'s
`ExpandFactionHeader(index)` open what they are given. Those change the interface in front of the
player, and the smoke row is where they are seen.

## 41. Probe version 16 on Midnight, and version 17 for the auction it missed (2026-09-24)

Ahia again, build 69933. Three of §40's four questions came back.

**An ordinary faction.** `GetFactionDataByIndex(3)` is *Gallagio Loyalty Rewards Club*, 2685: the
same seventeen keys, `isHeader = false`, a child, account-wide, `reaction` 5 with
`currentStanding` 3000 between 3000 and 9000. §39's mapping reads it as Friendly, nought of six
thousand, filed under *The War Within*. Index 4 is *Dragonflight*, a heading, as Druiduga's was.

**Two quest rows, and one of them corrects the fixture.** `GetInfo(2)` is *Broken Shore*, a
heading, **shut** (`isCollapsed = true`), twenty-five keys with no `campaignID`. `GetInfo(3)`,
right after it, is *Armies of Legionfall*, 48641, level 50 - **with `isHidden = true`**, a bounty,
twenty-five keys with `frequency` in place of `headerSortKey`. So:

- ~~**A shut heading does not keep the row after it out of the list.**~~ **Retracted in §43, and
  reinstated in §45** on a walk of the whole log - the conclusion was right, this row could not
  carry it (L-213). As first retracted: the
  row was hidden, so this one reading cannot tell a shut heading that hides nothing from a hidden
  row that is always listed. §37's fixture had the rows under a shut heading appear only once it
  was opened, which is what the Classic clients do and what nothing here had measured. The scan still opens
  every heading and shuts again the ones it found shut; whether that is needed on this client is
  not something a list can say.
- **Hidden rows are real, and the first one read is a bounty** - not a quest the player's log
  shows. §37 left them out on the strength of the key's name; this is the first row it applies
  to.
- `campaignID` and `headerSortKey` are not on every row. Nothing reads either.

Both fixtures now carry the measured rows - Broken Shore and Armies of Legionfall in the quest
log, Gallagio in the faction list - and only what has still not been read is the harness's: a
quest the player would see, and a partly filled bar. The twelve mutations of §37 and §39 were run
again against them: all caught.

**The quest history.** `C_QuestLog.GetAllCompletedQuestIDs()` answers **a list of 8410 ids**,
positional (`1=5`, `2=…`, `10=18`, `100=168`). That settles step 3 (e): the shape is a list of
ids, where `GetQuestsCompleted` filled a table keyed by id.

**The auction was up and not seen.** Alberto had an auction on the house; the reading says
`GetNumOwnedAuctions()` 0 and `GetOwnedAuctionInfo(1)` nil, so `GetItemKeyInfo` was handed nil
and threw its usage line. The probe asks the house two seconds after `AUCTION_HOUSE_SHOW`, and
the owned list is the client's only after it has asked the server for it - which the Auctions tab
does, and announces with `OWNED_AUCTIONS_UPDATED`. §35's reading of one row was the same window on
another day, so which of the two it depends on is not known from here. **Version 17** asks the
three owned reads again when that event arrives, at once and two seconds on, filed as
`auctionOwned`; a selftest claim covers it and was seen to fail with the event renamed. Family
itself scans on that event (§30), so this is the probe's gap and not the addon's.

## 42. Step 3 (e): the quest history read from `C_QuestLog`'s list (2026-09-24)

The last of step 3's five, and the one that arrived with 4.4.0 rather than with the branch.
`QuestHistory:Read` took a client without `GetQuestsCompleted` as one with no history; it now
hands that case to **`QuestHistory:ReadList`**, which asks `C_QuestLog.GetAllCompletedQuestIDs()`
through `TryCall` and takes the list's **values** as the ids - §41's reading is positional,
`1=5`, `10=18`, `100=168`. No list is still nil and still *no quest history on this client*; an
empty list is a reading of none, as the old call's empty table already was.

The old call's guard is `main`'s, `type(_G.GetQuestsCompleted) ~= "function"`, and it stays: the
change is what happens behind it. Everything after the read - the family pool, the six-bit flags,
`questsDoneCount` - is `main`'s code and unchanged.

The section on the fourth pretend client uses three ids from the measured list and puts the
family pool back as it found it, since the pool is the saved variables' and a later section may
read it. Five checks; three mutations - the list never asked, the list read by position (which
would say quests 1, 2 and 3 were done), and no list taken for an empty one.

**Not measured: whose list it is.** `IsQuestFlaggedCompletedOnAccount` sits beside
`IsQuestFlaggedCompleted` in the namespace, which suggests the account has its own calls and this
list is the character's. If it is the account's, every character on it would read the same
history; the smoke row is where two characters' counts are compared.

**Step 3's list of five is done.** What each slice still owes the game is written in §37 to §42;
the merchant through `C_MerchantFrame.GetItemInfo` was never on the list and is not done.
Harness 3870.

## 43. §41 retracted on the shut heading, and probe version 18 walks the whole log (2026-09-24)

§41 read Ahia's quest index 3 right after a shut heading and wrote that a shut heading does not
keep what follows it out of the list. **That was one row, and a hidden one.** Alberto's
screenshots of the log the same day show Drustvar shut with nothing under it and open with two
quests, Vol'dun and Artifact the same, and *Broken Shore* - the shut heading index 2 was - is not
drawn at all, which fits a heading holding only hidden rows. So the reading cannot tell *a shut
heading hides nothing* from *a hidden row is listed whatever its heading does*. What the player's
log draws is the interface's choice and not an answer from `C_QuestLog`, so the screenshots do not
settle it either; they show where the claim went further than its evidence.

The fixture goes back to hiding what is under a shut heading until it is opened - not as a claim
about this client, but because that is the case where a scan that failed to open every heading
would lose quests. The hidden bounty stays listed either way, which is what was read. The six
quest mutations of §37 were run again: all caught.

**Version 18** adds a login block, `questLog`: `C_QuestLog.GetNumQuestLogEntries()` with
everything it returns - its second value has never been seen - and `GetInfo` for every row, to two
hundred. Read with a heading shut that has visible quests under it, it answers the question
directly. `/familysurface` asks again without a relog. A selftest claim covers the block and was
seen to fail with the walk turned off; thirty-five claims.

## 44. Probe version 17: the owned auction, whole, and why version 16 missed it (2026-09-24)

Ahia with one auction up, the house opened and then its Auctions tab. Two readings of the same
row, a few seconds apart, say what §41 guessed:

| When | `GetNumOwnedAuctions()` |
|---|---|
| two seconds after `AUCTION_HOUSE_SHOW` (`auctionHouse`) | **0** |
| on `OWNED_AUCTIONS_UPDATED`, at once and two seconds on (`auctionOwned…`) | **1** |

**The owned list is the client's only once that event has come.** Family reads the house on the
same event (§30), so the addon was never exposed to this; the probe was.

The row is the six keys of §35 again - `auctionID` 963244795, `buyoutAmount` 17400, `quantity` 1,
`status` 0, `timeLeftSeconds` 85813 - and its key, printed whole as `GetItemKeyInfo`'s argument:

```
itemKey = {battlePetSpeciesID=0, itemID=2770, itemLevel=10, itemSuffix=0}
GetItemKeyInfo(itemKey) -> {itemID=2770, itemName="Copper Ore", isCommodity=true,
                            isEquipment=false, isPet=false, quality=1, iconFileID=134566, ...}
```

**`itemID` is in the key**, which is the only field `readModernOwned` takes from it, so a Midnight
owned row is recorded and §35's worry - a key without an id, dropped in silence - does not happen
on this row. It is also a **commodity**, listed by `GetOwnedAuctionInfo` like any other auction,
so the owned list is not split by kind on this client.

The fourth pretend client's auction section now uses this row whole; §35's made-up id is gone,
and nothing in that section is the harness's own any more. `a-midnight-owned-row-needs-a-link.mut`
is still caught.

The rest of the file repeats version 16: the same 8410 completed ids, the same faction and quest
rows. Version 18's walk of the log was not in this run.

## 45. Probe version 18 walks the log: a shut heading hides nothing from `GetInfo` (2026-09-24)

Ahia, Drustvar shut, `/familysurface`. The count answered **`46 | 22`**, and the walk read all
forty-six rows:

| Rows | Count |
|---|---|
| headings | 17, ten of them shut |
| quests the player's log can show | **22** - the count's second value, exactly |
| hidden rows | 7 - bounties and faction entries, *Armies of Legionfall*, *The Kirin Tor of Dalaran*, *The Valarjar*… |

**Every quest under a shut heading is listed**: sixteen visible quests under ten shut headings,
Drustvar's two among them - *A Steady Ballast* (50151) and *Through the Old Roads* (48504) at 9 and
10, straight after the heading at 8. A row under a shut heading carries **`isCollapsed = true`
itself**, inherited; `interpretInfo` takes `isCollapsed` only on a heading, so that is harmless.
The player's log does not draw those rows - Alberto's screenshots - and that is the interface's
doing. So §41's conclusion stands and §43's retraction of it is withdrawn; the evidence under both
was about something else (**L-213**).

**The count's second value is the visible quests.** That is what the summary's `questCount`
already arrives at by leaving out headings and hidden rows, so the scanner and the client agree
without the scanner reading it.

**The first visible quest row.** *Adventurers Wanted: Chromie's Call*, 62567, under *Stormwind
City*: twenty-five keys, the same set as the hidden bounty - `frequency` where a heading has
`headerSortKey`, no `campaignID`. Everything `interpretInfo` reads is on it.

**The fixture is now the client's, every row**: eight of the forty-six - *Dragonflight*,
*Stormwind City*, Chromie's Call, *Broken Shore* and its hidden bounty, *Drustvar* shut and its two
quests - keys and values as read, only `questLogIndex` renumbered. The scan finds the three visible
quests, files the two under Drustvar there, leaves the bounty out, counts three as the client's own
second value does, and shuts Drustvar and Broken Shore again, last first. Nothing in the section
is the harness's own any more. The six mutations of §37 still caught.

The scan still opens every heading with `ExpandQuestHeader(0)` and shuts again what it found shut.
On this client that is not needed to read the log; whether it disturbs the player's log is the
smoke row's to see.

## 46. Midnight's interface number goes into the `.toc` files now, to try Family at home (2026-09-24)

`addons/Family/Family.toc` and `addons/Family_UI/Family_UI.toc` read
`## Interface: 11509, 20506, 50504, 120100`. Until today they stopped at Mists, so Midnight would
not load them.

**This reverses step 4 of the branch's `CLAUDE.md`**, which put the number in only with the 5.0.0
merge so that the branch would not be installable on Midnight *by anyone who is not looking for
it*. Alberto, 2026-09-24: before any beta the software has to be tried on his own installations,
so it has to load there. The reason for the rule does not reach this case - `midnight` has no
remote branch and exists on this machine only - and a beta or the merge, which would carry the
number out, are both Alberto's.

The cost: when `main` changes its interface numbers for a Classic patch, the merge conflicts on
line 1 of both files, and is resolved here by keeping `120100` beside `main`'s new numbers.

### What to look at in the game

Copy `addons/Family` and `addons/Family_UI` from this worktree into `Interface/AddOns/` on
Midnight, by hand as the probe was. What step 3 left for the game to confirm:

1. **The quest log** (§37, §45): the member's quests are listed, including those under a heading
   shut in the player's log, and none of the hidden bounties; the log the player sees is left as
   it was found, shut headings still shut.
2. **Reputations** (§39): the factions are listed under their headings, *The Cartels of Undermine*
   among them; the reputation window is left as it was found.
3. **Professions** (§38): with a profession's window open, its recipes are recorded, and Family's
   way back into the profession opens the window.
4. **Auctions** (§44): an owned auction appears once the Auctions tab has been opened.
5. **Quest history** (§42): a quest's tooltip says who has done it, and two characters on the same
   account show different counts - or the same, which would mean the list is the account's.
6. **Everything that already worked** (§31): bags, bank, currencies, mail.

A red error on screen, or a panel empty where it should not be, is the finding; a screenshot with
the character's name is enough to start from.

## 47. The first run in the game: an empty window, and the tooltip hook that caused it (2026-09-24)

Family loaded on Midnight for the first time (§46) and its window came up with every tab button in
the same place and no panel. The broker's tooltip worked - Ahia, level 50, item level 49, money -
so the records were there. With `/console scriptErrors 1` the client named the cause:

1. **`Family_UI/Tooltip.lua:2114`** - `tooltip:HookScript("OnTooltipSetItem", …)` throws *bad
   argument #2 to '?' (Usage: local success = self:HookScript(scriptTypeName, script [,
   bindingType]))*. Midnight has no such script and refuses to hook one.
2. **That error stopped the whole file.** The hook runs in an `OnDatabaseReady` callback, and
   `Family:OnDatabaseReady` (`Core.lua:764`) calls the function **straight through** when the
   database is already up - which it is by the time `Family_UI` loads. So the error travelled up
   into `Tooltip.lua`'s main chunk at line 2122 and nothing after it was defined, `UI:AttachTooltip`
   (line 2552) included.
3. **`Family_UI/Window.lua:626`** - *attempt to call a nil value*: `RegisterTab` calls
   `UI:AttachTooltip` for each tab's star. Every tab died there, after its button had been made and
   labelled and before it was recorded, so every button took index 1 - the top slot - and the
   window had no tab to open. That is the screenshot.

**The fix is at the first error**: both old hooks, `OnTooltipSetItem` and `OnTooltipSetSpell`, go
through `Family:TryCall`. Where the client refuses them, the modern route registered just above
(`TooltipDataProcessor.AddTooltipPostCall`, already in a `pcall`) is what fires. The two installers
are reachable as `UI.__hookSetItem` and `UI.__hookSetSpell`, the way `UI.__modernCallback` is, and a
fourth-client section hands them a tooltip that refuses the old scripts with the client's own error
text - and one that accepts them, to see the hook still go in. Two mutations, both caught. Harness
3873. **The harness could not have seen this before**: every pretend tooltip accepted any script.

**Also in the error list, and not a fault:** *Error loading* for `Libs/LibStub`, `LibSerialize` and
`LibDeflate` (`Family.toc:39-41`). The `.toc` says why (lines 36-37): the libraries are absent from
a git clone and present in a release, and a file the client cannot find is skipped. A copy taken
from this worktree runs Wide Family without compression.

**Two things this leaves open.**

- **Everything after line 2122 of `Tooltip.lua` has never run on Midnight.** The next run may
  well show the next refusal; `scriptErrors` should stay on for the whole test.
- **`OnDatabaseReady` does not isolate its callbacks when it calls them straight through**, while
  event handlers are isolated (`Window.lua`'s comment on `ShowTab` says so). One refusal in one
  callback took out a whole file and, through it, the window. Isolating it would have left the
  window standing with only item tooltips missing - but it is `Core.lua`, shared with `main`, and
  changes what an error does on all four clients, so it is a question for `main` rather than a
  change made here.

## 48. `tools/DeployMidnight.bat`: this branch, to the Midnight client only (2026-09-24)

Asked for by Alberto: a deploy like `tools/Deploy.bat` that copies this branch's `Family` and
`Family_UI` and the probe to the Retail client and to nothing else. It has `Deploy.bat`'s shape and
guards - three folders named explicitly, `/MIR` aimed at each and never at `AddOns`, a refusal for
any destination that does not end in `Interface\AddOns`, `/test` and `/y` - and one guard of its
own: it **refuses a source whose `Family.toc` does not list 120100**, since that is `main`'s
checkout and Midnight would not load it.

- **Destination**: `E:\Giochi\World of Warcraft\_retail_\Interface\AddOns`, as Alberto gave it.
  `Deploy.bat` keeps its machine paths as placeholders because it is in a public repository; this
  one names no person, and it was given to be used.
- **Source**: the checkout beside the script, or `SRC_SHARE`, a placeholder for the share that
  reaches this worktree - it has to be set on the games PC, as `Deploy.bat`'s is.
- **The probe is `FamilySurface` only.** `FamilyProbe` and `FamilyIconSheet`, which `Deploy.bat`
  carries, stop at Mists in their `.toc` files and would not load on Midnight.

Not run here: this machine has no Windows. Its first run should be with `/test`.

## 49. A posted auction was not seen until the house was opened again (2026-09-24)

From the first in-game test (§46), Alberto: an auction posted on Ahia was not in the Summary
until the house was closed and reopened. With `/family debug` on, the chat said it in order:

| Moment | Family |
|---|---|
| house opened | `scanned auctions: 1 selling` |
| auction posted - *Auction created.* | no read; bags and currencies only |
| Auctions tab opened | `scanned auctions: 2 selling` |

The probe, beside it, printed no `auctionOwned` after *Auction created.*: **the client sends no
`OWNED_AUCTIONS_UPDATED` for a post.** The owned list comes back when it is asked for, and Family
asked only a second after the house opened (`Scanners/Auctions.lua`, `AUCTION_HOUSE_SHOW`).

So a post now asks, the same way: `QueryOwnedAuctions` a second after either of two signals -
`CHAT_MSG_SYSTEM` carrying the client's own `ERR_AUCTION_STARTED`, which is the *Auction created.*
Midnight printed, matched by the client's string and never the English (as `ERR_AUCTION_WON_S`
already is); and `AUCTION_HOUSE_AUCTION_CREATED`, **not measured on any client**, which answers
false where it is unknown. Both are handled on the one `CHAT_MSG_SYSTEM` registration the scanner
already had, rather than a second under the same key (L-068). The newer house only; the older one
sends its own owner-list event after a post.

**Not measured either: that `ERR_AUCTION_STARTED` exists on Midnight.** If it does not, the message
never matches and nothing changes from before. The game says which: post with `/family debug` on
and a `scanned auctions` line should follow *Auction created.* within a couple of seconds.

The fourth-client auction section's `fire` now passes the event and its arguments, as
`Core.lua:98` does, and three checks and three mutations cover the two signals and an unrelated
system message. Harness 3876.

This probably happens on Mists as well, which reads owned auctions from the same house; that is
for `main` to look at.

## 50. The sell price, per item beside the client's per stack (2026-09-24)

Midnight writes its own *Sell Price:* on an item's tooltip, and for **the stack under the
pointer**: on five Salty Dog Crackers (161053) it read *1g 10s*, and Family's line under it *0g
22s 00c* - one of them. Both right, and side by side they read as a contradiction. Alberto chose,
of three options, to mark Family's line only where the client has written its own: **"Sell Price
(each)"** there, the plain word everywhere else, so the Classic tooltips are unchanged unless a
Classic client prices the stack too.

Decided by the tooltip, not by the client: `clientShowsSellPrice` walks the tooltip's lines as
`requiredSkill` does and looks for the client's own `SELL_PRICE` followed by a colon. The colon is
what tells the client's line from Family's, which has none. One new sentence, `%s (each)`, in all
four locale files - the translation gate demands it. `UI.__priceLines` is reachable for the
harness, which prices the same crackers at 22s on three tooltips: one the client has priced, one it
has not, and one holding only Family's own earlier line. Three mutations.

Whether Midnight has a setting that switches its line to one item was asked and is not known here.

**Also from the test, and recorded rather than chased:** an `ADDON_ACTION_FORBIDDEN` for Family
arrived once, on turning on recipe materials; it did not happen again, so nothing is known of its
cause. `/console taintLog 1` is the way to name it if it returns.

## 51. §49 and §50 seen in the game (2026-09-24)

Alberto redeployed with `tools/DeployMidnight.bat` and tried both on Ahia:

- **§49, the posted auction:** *Auction created.*, then the probe's `auctionOwnedAtOnce` - so the
  client did send `OWNED_AUCTIONS_UPDATED`, because Family asked - and `scanned auctions: 3 selling`,
  without the Auctions tab being opened. Which of the two signals made the request, the system
  message or `AUCTION_HOUSE_AUCTION_CREATED`, the chat does not say; one of them did, so the owned
  list now follows a post.
- **§50, the sell price:** five Salty Dog Crackers, the client's *Sell Price: 1g 10s* and under it
  Family's **Sell Price (each)** *0g 22s 00c*.

## 52. Recipe materials on Midnight, and probe version 19 (2026-09-24)

From the in-game test (§46): **a recipe's materials are shown nowhere on Midnight** - not on an
item's tooltip, not in the recipe list. Not a fault in the drawing: Family does not ask the client
for materials. It ships them, generated by `tools/recipe-reagents.py` into
`addons/Family/RecipeReagents.lua`, keyed by expansion - and the table has sections for **1, 2 and
5 only** (lines 15, 1691 and 3997). Midnight, 12, has none, so every lookup answers nothing. The
table exists because on the Classic clients the client describes a recipe only with the window
open and only on the character who knows it (`Family_UI/Professions.lua:47`).

Two ways out, and which one is not known yet:

1. **Ask the client.** `C_TradeSkillUI.GetRecipeSchematic(recipeSpellID, isRecraft [,
   recipeLevel])` is on Midnight - its usage line was read by version 18's sweep. If it answers
   with no window open, and for a recipe the character does not know, Family can ask it for any
   member's recipe, and the table is not needed on this client.
2. **Generate a section for 12** from the same tables at Midnight's build. Whether that is the same
   data source as the Classic sections or a new one is a question for `docs/DATASOURCES.md`, and a
   new one is Alberto's to adopt.

**Version 19** asks the first: `GetRecipeSchematic(2657, false)` - Smelt Copper, an id written from
memory for a recipe a miner knows - and `(1260349, false)`, §26's engineering recipe, which Ahia
has not learned, at login where the brief runs; and the first listed recipe with a profession
window open, to compare. The materials are two levels down, so each slot is a line of its own
naming its first reagent, keyed as a pseudo-call. A selftest claim covers the reader and was seen
to fail with it broken; thirty-six claims.

## 53. Recipe materials asked of the client, and an item matched to a recorded recipe (2026-09-24)

**Probe version 19 answered §52's question: yes.** At login, with no window open, on Ahia:

| Recipe | `GetRecipeSchematic(id, false)` |
|---|---|
| 2657, *Smelt Copper* - the id written from memory was right | makes 2840; one slot, **1 × 2770** |
| 1260349, which Ahia has **not** learnt | five slots: 42 × 251768, 30 × 152579, 35 × 152512, 20 × 163569, 5 × 166970 |

With the engineering window open, 1260349 answered the same. Each slot is ten keys -
`quantityRequired`, `reagentType`, `required`, `reagents` (a list of `{ itemID }`) among them - and
every slot read was `required = true, reagentType = 1`.

So on Midnight **the client is asked, and nothing is generated**: no data source is added, and the
question §52 left for DATASOURCES does not arise.

- **`Recipes:Reagents`** reads the shipped table where the client has a book in it, exactly as
  before, and where it has none - told by `RecipeReagents[expansion]` - asks `GetRecipeSchematic`
  through `TryCall`. A slot's first alternative is taken; a slot marked not required is left out,
  since a recipe does not cost what it may optionally be given. Kept for the session, with `false`
  for a recipe the client would not describe so it is not asked again.
- **`Recipes:MadeBy`**, which the item tooltip starts from, had no route either: every table it
  reads is generated. Where there is no book - told by `RecipeProducts`, which has one for every
  generated client, and **not** by `RecipeMadeBy`, which has Era's alone: a first version asked the
  wrong table and would have taken Burning Crusade and Mists off their own route, which a mutation
  now holds - it matches the item to the lowest recipe any member is recorded as knowing, from the
  recipe and product ids `readModernRecipes` keeps (§38). That covers what somebody in the family
  can make; an item nobody has learnt to make has no recipe named on Midnight. The index is built
  once and dropped whenever the database says a record changed.

The fourth-client section uses the two measured schematics and one of the harness's own - two
alternatives in a slot and an optional slot, neither of which a run has shown - and a member
recorded as knowing Smelt Copper, forgotten again at the end. Eight checks, seven mutations.
Harness 3887.

**Not done and not known**: `BoundReagents`, which says which materials no money can buy, is
generated for the same three clients; on Midnight every material is priced as if it could be
bought. And whether a slot's first alternative is the lowest quality is the game's to say.

## 54. The blocked action: the profession button's cast (2026-09-24)

The *Family has been blocked from an action only available to the Blizzard UI* dialog of §47's
test came back, and Alberto tied it down: it comes **on pressing a profession button** in Family's
Professions panel, with the probe writing `ADDON_ACTION_FORBIDDEN "Family" | "UNKNOWN()"` each
time.

That button opens the profession's window two ways (backlog 61): as a secure button armed with
`type = "spell"`, and, because on Burning Crusade the secure button alone opened nothing, by
calling **`CastSpellByName`** from its `PostClick` - addon code. On the Classic clients that is
allowed from a click; measured on Burning Crusade 2026-09-11, *callWorked true*. On Midnight a
protected call from addon code is forbidden, and the client does not raise an error `TryCall`
could catch: it stops the call and asks the player whether to disable Family.

Whether an addon may cast is a rule of the game rather than a choice between two calls, so it is
data (§37): **`addonCasts`** in `Capabilities.lua`, true for Era, Burning Crusade and Mists -
confirmed on Burning Crusade - and, Midnight having no column, false there. The `PostClick` cast
asks the table first. The secure attributes are untouched, so whether the button still opens the
window on Midnight by that route alone is the game's to show; the dialog should not come back
either way. One check beside the existing ones, on the fourth pretend client's build, and two
mutations: the cast made regardless, and the Classic clients told they may not. Harness 3888.

## 55. Materials seen in the game, and gathering nodes left out of the recipes (2026-09-24)

**§53 seen on Ahia after redeploying.** The recipe list draws every recipe's materials on the right
of its row - *Smelt Copper* one Copper Ore, the three *Bolt-Action Headgun* rows 40, 50 and 30
Stormscale - and an item's tooltip carries *Made with*: Copper Bar, one Copper Ore; Bolt-Action
Headgun, Stormscale ×50, Sniping Scope ×2, Loose Trigger ×2, "Twirling Bottom" Repeater ×1. The
three rows of one name are **ranks with their own materials**, which is what the professions slice
needs to show them apart.

**Every price there reads *unknown*, and that is a reading, not a broken link.** Family prices a
material from a vendor seen selling it or from the auction house as searched, and on Midnight
neither has been seen: Possessions' header says *0 at auction prices*. Whether a search at the house
fills them on this client is not yet known - Copper Ore is a commodity, and the browse results
`ReadModernPrices` reads were measured on Mists and not here.

**Gathering nodes are recorded as recipes on Midnight.** Mining lists *Monelite Deposit*, *Storm
Silver Seam*, *Platinum Deposit*, *Living Leystone* - learnt, and nothing made from them.
`readModernRecipes` now leaves out a row whose `isGatheringRecipe` is true. The key is on every row
read (§26) and false on the engineering ones; **that it is true on a node is taken from its name**,
as `isHidden` was (§37, borne out in §45). If the nodes are still listed after the next mining
window is opened, the key is not what marks them. The professions section of the fourth pretend
client gains a learnt node of its own making, and its two existing checks - one recipe kept, one
recorded - now hold it out. One mutation. Harness 3888.

## 56. Recipe names: Midnight lists them as Era does, and nothing changes (2026-09-24)

From the in-game test Alberto noticed Midnight's mining list reading *Smelt Copper* where he
remembered the crafted item, and asked whether the names had changed. Checked on Era the same day,
on Verysolid, in the client's own window through Skillet and in Family's: **Era lists *Smelt
Copper*, *Smelt Iron*, *Smelt Thorium*** - the recipe's name - with the product, *Copper Bar*, on
its tooltip. Midnight does the same, and engineering, where a recipe is named after what it makes,
reads the same on both. So there is no difference to port, and the item is closed with no change.

## 57. A Midnight recipe's picture, from what the client says it makes (2026-09-24)

A dozen engineering rows on Ahia - *Cardboard Assassin*, *Frag Belt*, *Goblin Glider* - drew a
question mark. `recipeIcon` (`Family_UI/Professions.lua`) takes the product's picture, then the
recorded icon, then the spell's: those rows were recorded with no product, `Recipes:Product` reads
only the generated `RecipeProducts`, which has no book for Midnight, and the spell's picture comes
through `GetSpellInfo`, which Midnight does not have.

The schematic the client answers carries the product - `outputItemID`, 2840 for Smelt Copper and
246604 for 1260349 (§53) - so the client reader now keeps it beside the materials, one cached answer
per recipe, and `Recipes:Product` asks it where there is no book. The reader moved above `Product`
in the file, since a local function is not seen from above its definition. One check, two
mutations; two §53 mutations and `main`'s `recipe-spell-names-no-product.mut` were anchored on the
lines rewritten and were moved to them, `mutate.py` having refused them as moved anchors rather than
passing them. Harness 3889.

**Also from the same test, and open:** the Mining list still carries its deposits and seams after
the window was opened again (§55). Either the copy in the game predates the filter, or
`isGatheringRecipe` is not what marks them - the game files them under *Mining Techniques*, with
ranks. A `/run` asking the client about *Monelite Deposit*'s row settles which. And the same window
shows Mining's per-expansion ranks, the shape the professions slice needs: Kul Tiran 157/175, Legion
100/100, Draenor 100/100, Pandaria to Outland 75/75, Classic 300/300.

**And slowness, not yet measured:** opening Engineering, 440 recipes, took fifteen to twenty
seconds to draw its pictures, every session. The list draws every row on each refresh, and on
Midnight each row asks the client for its schematic the first time in a session. That is the
suspect, not the finding.

## 58. Gathering techniques are the game's own list, so the filter comes out (2026-09-24)

§55 left gathering nodes out of a modern recipe list. It did not take in the game - the Mining list
still had its deposits after the window was reopened - and before the reason was chased Alberto
looked at the game's own window and found that the filter was wrong in what it meant, not only in
how it worked:

- **Kul Tiran Mining lists no smelting at all.** Its window has one category, *Mining Techniques*:
  *Monelite Deposit*, *Monelite Seam*, *Platinum Deposit*, *Storm Silver Deposit*, *Storm Silver
  Seam*, each ranked in stars (*Monelite Deposit* three of three), and *Osmenite Deposit* and
  *Seam* unlearnt. Recipes of that line take ores directly, and the ore's own picture on the
  tooltip is the deposit's.
- **The older lines keep smelting**, under a *Smelting* category: Pandaria Mining 75/75 lists
  *Smelt Trillium* and *Smelt Ghost Iron*, Cataclysm Mining 75/75 *Smelt Hardened Elementium*,
  *Pyrite*, *Elementium* and *Obsidium* - the old metals still need a forge.
- **Engineering's recipes are ranked too**: *F.R.I.E.D.* two stars of three, with *Next Rank*.

So the techniques are what the game shows for that profession on that line, and Family shows what
the game shows: `readModernRecipes` keeps everything the client lists as learnt, as it did before
§55. What makes the list readable is not hiding them but the professions slice - each expansion line
with its own rank (Kul Tiran 157/175, Legion 100/100, Draenor 100/100, Pandaria to Outland 75/75,
Classic 300/300), recipes under the game's categories, and each recipe's rank - which also explains
the three *Bolt-Action Headgun* rows of §55.

Alberto chose option 1 of two: remove the filter, rather than hide the techniques by category. The
fixture's technique of its own making is kept, and the professions section now records it; the
mutation written for the filter is turned round and renamed (`a-gathering-technique-is-dropped-from-
the-list.mut`) so that dropping it is what fails. Harness 3889.

**Where a recipe's rank lives in the client's answers is not known yet**: the 28-key row of §26 has
no key that plainly names one. A probe line on a ranked row is the first step of that slice.

## 59. Recipe ranks: one row, the highest learnt, and which rank it is (2026-09-24)

Three *Blink-Trigger Headgun* rows in Family's engineering list, where the game's own window shows
one, with three stars and 30 Shal'dorei Silk. Alberto: the rows of one name are ranks, each needing
less material, and Family does not say which is which; the game shows only the highest, and a
lower rank is never used again. Legion Mining showed the same - *Felslate Deposit* twice, *Infernal
Brimstone* three times.

**Read on Ahia with `/dump C_TradeSkillUI.GetRecipeInfo`**, all three learnt:

| Recipe | `previousRecipeID` | `nextRecipeID` | `maxTrivialLevel` |
|---|---|---|---|
| 198939 | - | 198991 | 40 |
| 198991 | 198939 | 199005 | 60 |
| 199005 | 198991 | - | 80 |

The rest of each row is the same - name, icon 1391897, category 470, and the product, item 132500,
in `hyperlink`. **The ranks are a chain, and the two keys are there only where there is a link**,
which is why §26's row, a recipe with no ranks, never showed them.

So `readModernRecipes` now leaves out a learnt recipe whose next rank is also learnt, and on the one
it keeps writes `rank` - counted back along `previousRecipeID` - and `ranks` - that plus the ranks
counted forward along `nextRecipeID`, learnt or not. Bounded at twenty, since a chain answered in a
circle would not end. A row with neither key carries neither field, so every Classic client, and
Midnight's unranked recipes, read as before. The recipe list draws the rank beside the name in
grey, *3/3*. The item tooltip follows by itself: with the lower ranks no longer recorded, the
recipe `MadeBy` finds for the Headgun is the top rank, so *Made with* shows its 30 silk and not
rank one's 50.

The professions section of the fourth pretend client carries the three measured rows whole and a
chain of its own of two whose top is not learnt, which keeps its learnt rank as one of two; a
Classic panel check draws a recipe with a rank. Five mutations; the §58 mutation anchored on the
line extended here was moved. Harness 3894.

Records made before this carry every rank until the profession's window is opened again.

**And the question marks, explained.** *Cardboard Assassin* is a Cataclysm tinker: it makes no
item, the client gave its row the question-mark picture (134400), and the game's own window draws
the **spell's** picture, a gear. `recipeIcon` would take the spell's picture last, through
`GetSpellInfo` - which Midnight does not have. That belongs with the spellbook gap (§23), not here.

## 60. §59 seen in the game (2026-09-24)

Alberto redeployed and reopened both windows on Ahia. **Engineering went from 440 recipes to 403
and Mining from 65 to 46**, one row per recipe: *Blink-Trigger Headgun 3/3* with 30 Shal'dorei Silk,
the game's own figure; *Bolt-Action Headgun 3/3*; *F.R.I.E.D. 2/3*, two stars of three in the game's
window; *Crow's Nest Scope 1/3*; and on Mining *Felslate Deposit 2/3*, *Infernal Brimstone 3/3*,
*Empyrium Seam 1/3*. The tinkers still draw a question mark, which is §59's spell-picture gap.

## 61. Probe version 20: a profession's lines, and where a recipe sits in them (2026-09-24)

The professions slice is to lay a Midnight profession out as the game's window does: one line per
expansion with its own rank - Kul Tiran Mining 157/175, Legion 100/100, Classic 300/300 in Alberto's
screenshot - and recipes under the game's categories, *Goggles* under *Legion Engineering*,
*Smelting*, *Mining Techniques*. Family knows none of it today: one rank per profession, the parent's
or a child's (§12 found the summary showing Kul Tiran's 55/180), and a flat list.

Three questions, asked with the window open and at login, where the brief runs:

1. **Each line's rank.** `GetChildProfessionInfos()` answered eight tables with the window open and
   none at login (§12); version 20 prints each table on its own line.
2. **Which line a recipe is on.** `GetTradeSkillLineForRecipe(recipeID)` - its usage line read in
   version 18 - for the first recipe listed, Smelt Copper (2657) and Blink-Trigger Headgun's top
   rank (199005).
3. **What a category is called.** The recipe row carries `categoryID` (470 for the Headgun, §59);
   `GetCategoryInfo(categoryID [,tableToUse])` for it and for the category above it, if it names
   one.

A selftest claim covers the second and third and was seen to fail with the reader switched off;
thirty-seven claims.

## 62. Probe version 20 answered: lines, ranks and categories (2026-09-24)

Ahia, Mining's window open last (a window's block is replaced when another opens, so this run's
`tradeSkill` block is Mining's).

**Each line's rank, with the window open** - `GetChildProfessionInfos()`, eight tables of eleven
keys, one per expansion: `professionID` 2565 *Kul Tiran Mining* 157/175, 2566 *Legion* 100/100,
2567 *Draenor* 100/100 (`skillModifier` 10), 2568 *Pandaria*, 2569 *Cataclysm*, 2570 *Northrend*,
2571 *Outland* 75/75 each, 2572 *Classic* 300/300; every one `parentProfessionID` 186, *Mining*, with
`expansionName`, `skillLevel`, `maxSkillLevel`. Exactly the game's dropdown.

**Which line a recipe is on, window open or shut** - `GetTradeSkillLineForRecipe(id)` answers three
values, the line, its name and the parent, **at login as well**: 296147 → 2565 *Kul Tiran Mining*
186; 2657 Smelt Copper → 2572 *Classic Mining* 186; 199005 Blink-Trigger Headgun → 2500 *Legion
Engineering* 202 - asked from the Mining window, so a recipe of another profession answers too.

**Categories are a tree, and the line is in it.** Mining's first recipe, 296147, is in category 1079
*Mining Techniques* (`type` subheader), whose parent 1065 is *Kul Tiran Mining* - with
`hasProgressBar` true, `skillLineID` 2565, `skillLineCurrentLevel` 157, `skillLineMaxLevel` 175 -
whose parent is 1064. Smelt Copper is in 264 *Smelting*, parent 1078 *Mining* on line 2572 at
300/300. So a recipe's category names the heading, and the category above it is the expansion line
with its rank.

**A recipe's `categoryID` is 0 unless its own profession's window is open**: 199005 read from the
Mining window, and both ids at login, gave `GetCategoryInfo(0)` and nothing. The category has to be
written down while the window is open - which is when Family reads recipes anyway.

What the professions slice now has to go on: the line of every recipe (any time), the category and
its parent line with its rank (window open), and every line's rank (window open).

## 63. A profession laid out by expansion line (2026-09-24)

Written against §62. With a profession's window open, `readModernRecipes` now writes on every
recipe its **line** (`GetTradeSkillLineForRecipe`, the id) and its **category** (the name
`GetCategoryInfo` gives for the row's `categoryID`, asked once per category, never for 0), and
hands back the profession's **lines**: `GetChildProfessionInfos()` in the client's order - id,
name, rank, cap - followed by any line a recipe named and that list did not, with no rank. The
lines are stored beside the recipes, `professions[id].lines`, and replaced with them.

The panel groups a profession **only when its recipes span two lines or more**: a heading per line
with its name and rank (*Kul Tiran Mining 157/175*), in the stored order, then a heading per
category, by name, with the recipes that have none first under the line alone. Within a category
the player's sort holds. A list on one line - every Classic one, and Mists, where a profession is
one line (§9) whatever these calls answer there - is drawn flat, as before.

Chosen here and not measured: categories by name, because the two subheaders read carry
`uiOrder` 0 and so order nothing; headings not foldable, as the game's are, which can follow if a
long list asks for it. What to look at in the game: Mining and Engineering on Ahia, each line under
its heading with the rank the game's dropdown shows, and the recipes under the game's categories.

## 64. §63 seen in the game, and the lines made to open and shut (2026-09-24)

Alberto's screenshots of Ahia after redeploying: Engineering under *Kul Tiran Engineering 55/180*
with *Bombs*, *Conversions*, *Devices*, and the Kul Tiran, Legion and Draenor lines first, as the
game has them. Mining under *Pandaria Mining 75/75*, *Cataclysm*, *Northrend*, each with its
*Smelting*.

**Mining's gathering techniques are not on their lines.** The Kul Tiran, Legion and Draenor
techniques came out together under one *Mining Techniques* heading **at the end** of the list. At
the end is where a recipe goes when it has no line or a line the rank list does not name - so
`GetTradeSkillLineForRecipe` answered something other than 2565, 2566 or 2567 for them, although it
answered 2565 for 296147 in §62. Which it answered is not known; a `/run` is asked for before
anything is changed.

**Asked for, and done: each line opens and shuts on a click of its heading, for every profession
laid out in lines.** Shut, a line is one row - `+`, its name, its rank, how many recipes it holds -
so a profession opens as the list of its expansions; open, `-`, with its categories and recipes
under it. Every line starts shut, and is shut again whenever the page changes, by the rule
`Window.lua` gives every unfold. A search opens them all, because a match hidden under a shut
heading is a match not found. The marker is text: a texture cannot be probed.

## 65. The `/run` of §64 answered: a technique's line is its profession (2026-09-24)

Ahia, Mining window open, every learnt recipe not named *Smelt*: `id name categoryID` and what
`GetTradeSkillLineForRecipe` answers.

- **Every gathering technique answers `186 Mining nil`** - the profession itself, and no parent.
  Kul Tiran's (*Monelite Deposit* 253333-5, *Monelite Seam*, *Platinum Deposit*, *Storm Silver
  Deposit* and *Seam*) are in category **1079**; Legion's (*Empyrium*, *Felslate*, *Infernal
  Brimstone*, *Leystone*, *Living Felslate*, *Living Leystone*) in **1080**.
- **Everything else answers a line with its parent**: *Earth Shatter* 35750 and *Fire Sunder*
  35751, category 265, `2571 Outland Mining 186`; *Enchanted Thorium Bar* 70524, 264, `2572
  Classic Mining 186`.

So §62's 296147 → 2565 is not what a technique answers. The panel's `+ Mining (14)` at the foot of
Alberto's screenshot after the fold landed is these fourteen, filed under line 186.

**The fix: where the answer has no parent, the line is read from the category tree** - walked up
from the recipe's category to the first with `hasProgressBar`, whose `skillLineID` is the line: 1079
→ 1065 *Kul Tiran Mining* 2565 (§62). Not the first with a `skillLineID`, because 1079 carries 186
without a bar. **1080's parent has not been read**; that it is *Legion Mining* 2566 is what the
walk expects, and the panel will show whether it is. Where the walk finds nothing, the answer is
kept as it was, which the harness does not exercise.

## 66. §65 seen in the game (2026-09-24)

Alberto's screenshot of Ahia's Mining after redeploying and opening the window: *Kul Tiran Mining
157/175* first, open, with *Monelite Deposit* 3/3, *Monelite Seam* 3/3, *Platinum Deposit* 2/3,
*Storm Silver Deposit* 3/3 and *Seam* 3/3 under *Mining Techniques*; then *Legion Mining 100/100*
with *Empyrium Deposit* 2/3, *Empyrium Seam* 1/3, *Felslate Deposit* 2/3 under its own *Mining
Techniques*. The `+ Mining (14)` line is gone. So 1080's line is *Legion Mining*, as the walk
expected: §65's one unread step is now seen.

## 67. The status line names the line the rank is (2026-09-24)

Alberto on the buttons showing *Engineering 55*: *does this make sense? Maybe yes.* The number is
the client's own answer for the profession, and it is one line's - *Kul Tiran Engineering* 55/180,
line 2499, which `GetProfessionChildSkillLineID()` answers with the window open (§12). The button
keeps it. The status line under the sort buttons said *Engineering 55/180* above a list of every
line with its own rank, which reads as the whole profession's; asked for and done, it now names the
line. The scan marks that line `current` among the stored lines, and the panel names it where one
is marked.

**Cooking's six *Way of* lines** answered Alberto's `/run` with their recipes' lines and parent:
104298 *Charbroiled Tiger Steak* category 64, `975 Way of the Grill 185`; 104301 *Sauteed Carrots*
65, 976 *Wok*; 104304 *Swirling Mist Soup* 66, 977 *Pot*; 104307 *Shrimp Dumplings* 67, 978
*Steamer*; 104310 *Wildfowl Roast* 68, 979 *Oven*; 124052 *Ginseng Tea* 69, 980 *Brew*. Each is a
child line of 185 *Cooking* with a parent, so the category walk of §65 is never asked for them, and
none is in `GetChildProfessionInfos()`, which is why they were drawn after every listed line. Where
they belong - under *Pandaria Cooking* or beside it - waits on what categories 64 to 69 sit under.

## 68. Cooking's *Way of* lines placed under the line above them (2026-09-24)

The second `/run` of §67, category 64 walked up on Ahia with the Cooking window open:

    64 Way of the Grill 975 true
    90 Pandaren Cuisine 2544 true

So a *Way* is a line of its own, 975, with a bar, in a category that sits under 90 *Pandaren
Cuisine* on line 2544, also with a bar - and 2544 is taken to be one of Cooking's listed lines,
*Pandaria Cooking*, which is **not read**: the panel will show it. 90's parent is not printed, so
it has none.

The rule of §65 is widened to cover both: **where a recipe's line answer has no parent or is not
one of the listed lines, the categories are walked up to the first with a bar whose line is
listed**, and where none is, to the first with a bar at all. With no line listed only an answer
with no parent is walked, so a client that lists none keeps every line it answers. A heading whose
category has a bar keeps its own rank beside it, *Way of the Grill 5/25* in the harness's figures.

Why the line reads *Pandaria Cooking* and not *Pandaren Cuisine*, as Alberto asked: a line's
heading is named from `GetChildProfessionInfos()`, the list behind the game's expansion dropdown;
*Pandaren Cuisine* is category 90's name, which the game's own recipe list prints. The dropdown's
name was taken because the category above Classic Mining's headings is called only *Mining*
(§62).

## 69. The Midnight PTR becomes the test client (2026-09-25)

Alberto: the live Retail client runs without Midnight bought, and the PTR runs the full latest
content without it too, so the PTR is now the test environment. What it opens that the live client
could not: the current expansion's lines, recipes and zones on a character that has them.

What follows from it:

- **Every reading says which client it was taken on**, live or PTR, with the build. A PTR build
  can be ahead of live, and what ships has to run on live: a PTR answer is a question for live
  where the two may differ, as a `main` answer is for Midnight.
- **The PTR has its own install folder and its own interface number.** `tools/DeployMidnight.bat`
  copies to the live client only, and the `.toc` files list `120100`; both wait on the PTR's
  folder and `GetBuildInfo()`, asked for 2026-09-25.
