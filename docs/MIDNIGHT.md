# Midnight — what Family asks of the client, and what Midnight answers

The first step of the `midnight` branch, and the one everything after it is written from: which
of the things Family calls Midnight **lacks**, which it has and **answers differently**, and
which it has and **throws**. Measured in a running Midnight client, never from pages about Retail.
The thesis of `addons/Family/Capabilities.lua` holds here more than anywhere: the client's symbol
surface is not evidence about the game.

This file lives on the branch and lands with it. At 5.0.0 what it found moves into
`DATASOURCES.md` §2 and `Capabilities.lua`, and this file goes.

## 1. What Family touches, counted 2026-09-18

Counted by `tools/surface.py` from the sources at `2d9780c`, the compiler's bytecode listing for
globals and the source for what the listing cannot see:

| Surface | Count |
|---|---|
| Globals Family reads that Lua does not define | 193 |
| Members of `C_*` namespaces, `Enum` and `TooltipDataProcessor` | 39 |
| Upper-case string literals, asked about as events | 136 |
| Frame templates, with the frame type each is built on | 6 |

The names themselves are in `tools/FamilySurface/Surface.lua`, which is generated and is the
list. It is not copied here, so it cannot drift from a second copy. `tools/surface.py --check`
says whether it is still current. It is to be run after every `git merge main`.

## 2. How Midnight is asked

`tools/FamilySurface`, a throwaway addon, run once on Midnight and once on Mists for comparison.
It records the type of every name, whether every literal registers as an event, whether every
template builds, and the answer or the error of 99 read-only calls. Its README says how to run
it.

## 3. What Midnight answered

Midnight 12.1.0, build 69875, interface 120100, on 2026-09-19: one login, an enUS level-50
rogue in a guild, no window open. The saved variables are not in the tree, because they hold a
character, a realm, a guild's name and notes, and gold. What follows is derived from them by
`tools/surface.py --report`, which also names the files. **The Mists control run has not been
done yet.** So "absent" below means absent on Midnight. Some of these names Mists lacks too,
and there Family already copes.

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

### Still to do for step 1

1. The Mists run, then `tools/surface.py --report <Midnight file> <Mists file>`. That separates
   the absences Family already copes with from the ones it has never met, and it turns the
   answers above into same shape or different shape.
2. Windows this login did not open: a trade skill, the auction house, the bank, a mailbox, a
   merchant. The probe asks outside them. Whether the present calls answer inside them is a
   separate run with each window open.

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
