# Family Surface

A throwaway addon that asks one client about everything Family touches. **Not part of Family**
and never shipped with it; it lives in `tools/` for that reason, beside `FamilyProbe`.

## Why

The Midnight branch starts by writing down, from a running client, which of the calls Family
makes Midnight lacks, which it has and answers differently, and which it has and throws. Not
from memory and not from pages about Retail: `Capabilities.lua` records four times the client's
own symbol table was wrong about the game, and one function (Anniversary's `GetNumSpecGroups`)
that exists and throws.

So for each name it asks the question that can actually be answered:

| What | Asked how | Recorded |
|---|---|---|
| 278 globals and 56 namespace members Family reads | looked up | the type, the value of a number or string, or `nil` |
| 136 upper-case string literals | `RegisterEvent` in a `pcall`, as `Family:RegisterEvent` does | `registers` or the refusal |
| 6 frame templates | built on the frame type Family builds them on | `builds` or the error |
| 100 read-only calls at login | called, with the smallest sensible arguments | every return, tables one level deep, or the error |
| 43 read-only calls in five windows | called two seconds after the window opens, with Family's own arguments | the same, filed under the window |
| every `C_` namespace Family uses | its keys listed | the names of the functions it holds |
| container ids -20 to 40 | slot count asked at login and with the bank open | which hold slots, and the first item in each |
| `C_MerchantFrame`, named from memory | its keys listed; at a vendor, each `Get…` and `Is…` function called with 1 | the answers, filed under the merchant |
| every `C_` namespace the client has | counted | `census`: each name with its number of functions |
| the nine namespaces the relayed briefs name and Family has never used (`C_Reputation`, `C_MajorFactions`, `C_Bank`, `C_WeeklyRewards`, `C_MythicPlus`, `C_PetJournal`, and from the second brief `C_Garrison`, `C_ToyBox`, `C_Heirloom`) | their function names listed on every client; a hand-written call each **only where the sweep is allowed** | listed under `(brief)`, called under `brief` |
| `Enum.BagIndex` and `Enum.BankType` | read as tables, called never | listed under `(enum)` - the brief puts the warband bank at `AccountBankTab_1`, and the container sweep found 12 |
| the same reads out of combat and two seconds into a fight | asked at login, and again on `PLAYER_REGEN_DISABLED` | `combatOut` and `combat`, to be compared - the brief says Midnight answers unreadable *Secret Values* in combat |
| namespaces whose name holds a word from the briefs (`Prof`, `Trade`, `Craft`, `Trait`, `Talent`, `Catalyst`, `Housing`, `House`, `Decor`, `Neighborhood`) | listed; **on Midnight only**, every `Get…`, `Is…`, `Can…` and `Has…` called with no arguments, at login and with a profession window open | filed as `discovery`, and under the trade skill |
| every profession skill line the client lists | its details, its concentration currency and that currency's details; `GetProfessionInfo` 1 to 6; the specialisation count of classes 1 to 14; every currency in the list; the treasure quest 89117 | filed as `professions` |
| the merchant, a second time | asked the moment the vendor opens as well as two seconds later, with `MerchantFrame:IsShown()` each time | filed as `merchantAtOnce` and `merchant` |
| the PvP reads of the second brief (`UnitHonor`, `UnitHonorMax`, `UnitHonorLevel`, `UnitPVPRank`, `GetPVPRankInfo`, `GetPVPLifetimeStats`, `GetPVPSessionStats`, `GetPVPYesterdayStats`) | looked up on every client; called **only where the sweep is allowed**; honour and conquest asked by id, 1792 and 1602, everywhere | filed as `pvp` |
| the two lockout reads (`GetNumSavedInstances`, `GetSavedInstanceInfo`) | the same way - the brief claims they are the same call on every client, and presence is what that claim is about | filed as `lockouts` |
| 13 event names the brief uses and Family does not | `RegisterEvent` in a `pcall`, with the generated literals and into the same block, so the report compares them against the control; a name no Family file mentions prints as `(no file found)`, which is where it came from | filed with the events |
| every `WOW_PROJECT` constant the client has | swept by prefix and read as a value, called never | filed as `project` |
| whatever the client blocks | the two blocked-action events registered in a `pcall`, their arguments written down as they arrive and printed in chat at once, **with the call this file was making at that instant** - Midnight names the function `UNKNOWN()` every time, so the probe's own bookkeeping is the only thing that can say which it was | filed as `blocked` |

The first three lists are `tools/surface.py`'s, generated from the Family sources into
`Surface.lua`; the counts above are what it wrote on 2026-09-19. The first two runs, on
Midnight and Mists that day, asked an earlier list of 193 and 39 that missed every name Family
reads through `_G.` or through a local alias of a namespace (L-103). The literals are generous on
purpose: some are events and some (`TOPLEFT`, `HEADSLOT`) are not and are refused everywhere,
so only a refusal **Midnight gives and a Classic client does not** means anything. That is why
one Classic run is part of the job and not an extra.

The calls are the one hand-written list, because only a person can say a call is safe. Nothing
that opens a window, queries the server or changes the character is called; those are only
looked up.

## The reads it calls, and the actions it does not

A namespace matched by a word from the briefs has its functions called with no arguments, and
which ones is decided by the name: `Get`, `Is`, `Can` or `Has`, **as a whole word** - the letter
after the prefix must be upper case.

That last clause was missing until version 10. `^Can` matches `Cancel`, so version 9's run on
Midnight called twelve `Cancel…` functions, ten of which executed without error:
`C_AuctionHouse.CancelAuction()`, `CancelSell()`, `CancelCommoditiesPurchase()`,
`C_TradeSkillUI.CancelProfessionRespec()` and six housing editors. Nothing is known to have been
changed by any of them - `CancelAuction()` was given no auction to cancel - and that is luck
rather than a property of the probe (`docs/LESSONS.md` L-205, and L-207 for the several hours in
which this file said otherwise). The decision of 2026-09-19 had justified the sweep with *actions
are never called, since no action is named that way*; that is false, and `Cancel` is how.

`Get`, `Is` and `Has` showed no such over-match across the 639 names that run swept, but all four
go through one function with the same rule, because what failed was the shape of the test and not
the word it was applied to. A name that begins with a read word and continues it - the near miss,
and only the near miss - is **written into the run** under its namespace, so the next reader audits
the filter by reading a line instead of by watching something happen.

## The one call it will not make on a Classic client

Calling a function with no arguments to read the error it gives back is how the sweep above
learns what a call wants. Version 6 did that on every client, and on **Mists 5.5.4 it took the
process down** twice, 28 seconds into the world: `ACCESS_VIOLATION` at address 0, with
`C_Housing.GetMaxHouseLevel()` on the Lua stack - the call that answers `12` on Midnight. The
three `pcall`s between it and the login timer caught nothing, because a native null dereference
is not a Lua error (`docs/LESSONS.md` L-200).

So from version 7 the sweep runs at **interface 120000 and up** and nowhere else, and a run below
that writes one `discovery` line saying it was skipped. Everything else - the surface, the
literals, the templates, the hand-written calls, the container sweep, the census, the profession
skill lines - runs on every client as before.

## Before the folder is handed over

    lua5.1 tools/FamilySurface/selftest.lua

**This is run in the session, not by the person at the client**, and its result is reported with
the folder - its claims and an exit status, or the folder does not go. It needs only `lua5.1`
and this repository, so there is nothing about it that the machine holding the game is better
placed to answer, and asking for it at the far end is how a gate turns into a request that is
sometimes skipped.

It loads the addon with the real generated list, stubs the login path and fires `PLAYER_LOGIN` at
interface 50504 and at 120100. Twenty-five claims: that an action whose name begins with a read
word is not called even where the sweep runs, that the predicate which only looks like it still
is, that the near miss is written down; that the sweep and both briefs' calls stay away
from the first and still run on the second, that a skipped block says why it is short, that a
currency and the warband enumeration are written down whole, that a refused event is written down
rather than dropped, that the `WOW_PROJECT` constants are found by their prefix and not by being
named, that every line of the new blocks is one `tools/surface.py` can key and compare, and that
the out-of-combat reading is taken. It says nothing about what a client answers; it checks what
the probe does to a client.

Each claim was checked by breaking the thing it guards and seeing it go red - removing the
interface floor, raising it out of reach, dropping the names `guarded` writes down, dropping a
refusal and naming the constants instead of sweeping for them. The mutations recorded in
`tools/mutations/` cannot cover this file: their gate is `lua5.1 tests/Harness.lua .`
(`tools/mutate.py:66`), and the probe is deliberately outside the harness.

## Running it

1. Copy the `FamilySurface` folder into `Interface/AddOns/` on the **Midnight** client. **By
   hand: `tools/Deploy.bat` does not carry this tool and should not.** That script puts Family
   where Family is released - its four destinations are Classic Era, Anniversary, Mists and a
   Google Drive folder (`Deploy.bat:90`, `:91`, `:92`, `:105`) - along with the two development
   tools that answer questions on those three clients as a matter of routine. This one is a
   throwaway for a client Family is not released on, copied for a measuring run and deleted at
   5.0.0, so it would not belong there even at no cost. Alberto, 2026-09-20.
2. Its `.toc` carries Midnight's interface number, `120100`, read off a 12.1.0 client with
   `/dump select(4, GetBuildInfo())` on 2026-09-19. Without it Midnight marks the addon
   incompatible and does not load it. When
   Midnight moves to a new version, read the number again and add it here first.
3. Log in. It prints one line in chat five seconds later; `/familysurface` runs it again.
4. **Open each window once**, on a character that has something in it, and wait for its line
   in chat (*tradeSkill: 14 calls asked*, and so on) before closing it:
   - a profession's window;
   - the auction house, and its tab listing your own auctions, with at least one up;
   - the bank;
   - a mailbox, with at least one letter in it;
   - any vendor.
5. **Pick a fight with something harmless** and stay in combat for a few seconds. That is the
   other half of the Secret Values comparison, and without it there is only the out-of-combat
   reading. Wait for *combat: 13 calls asked*.
6. **Log out.** That is when the client writes the file.

   Version 9 asks three more blocks - PvP, lockouts and the `WOW_PROJECT` constants - and
   thirteen more event names, and **none of them needs a window**, so the steps above are the
   whole job. They are asked at login, with the rest.
7. Do the same on **Mists**, which is the Classic client whose API is nearest Midnight's and
   so gives the useful comparison. Use a character with a guild and a profession: an empty
   answer is recorded as the character's state and compares with nothing. The sweep does not
   run there (above), so the `discovery` block will hold one line saying so - that is the
   correct reading, not a failed one.
8. Send back `WTF/Account/<ACCOUNT>/SavedVariables/FamilySurface.lua` from each.

Runs accumulate under the build and the character, so a second character adds rather than
overwrites; opening a window again replaces that window's answers for the login.

## Afterwards

`docs/MIDNIGHT.md` is where the answers go. After every `git merge main`, run
`tools/surface.py --check`; if it says the list is out of date, regenerate it and ask the
client again about whatever is new. Delete this tool when the branch lands, as 5.0.0.
