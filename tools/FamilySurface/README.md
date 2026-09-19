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

## Running it

1. Copy the `FamilySurface` folder into `Interface/AddOns/` on the **Midnight** client.
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
5. **Log out.** That is when the client writes the file.
6. Do the same on **Mists**, which is the Classic client whose API is nearest Midnight's and
   so gives the useful comparison. Use a character with a guild and a profession: an empty
   answer is recorded as the character's state and compares with nothing.
7. Send back `WTF/Account/<ACCOUNT>/SavedVariables/FamilySurface.lua` from each.

Runs accumulate under the build and the character, so a second character adds rather than
overwrites; opening a window again replaces that window's answers for the login.

## Afterwards

`docs/MIDNIGHT.md` is where the answers go. After every `git merge main`, run
`tools/surface.py --check`; if it says the list is out of date, regenerate it and ask the
client again about whatever is new. Delete this tool when the branch lands, as 5.0.0.
