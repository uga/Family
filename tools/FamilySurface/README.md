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
| 193 globals and 39 namespace members Family reads | looked up | the type, or `nil` |
| 136 upper-case string literals | `RegisterEvent` in a `pcall`, as `Family:RegisterEvent` does | `registers` or the refusal |
| 6 frame templates | built on the frame type Family builds them on | `builds` or the error |
| 99 read-only calls | called, with the smallest sensible arguments | every return, or the error |

The first three lists are `tools/surface.py`'s, generated from the Family sources into
`Surface.lua`; the counts above are what it wrote on 2026-09-18. The literals are generous on
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
4. **Log out.** That is when the client writes the file.
5. Do the same once on **Mists**, which is the Classic client whose API is nearest Midnight's
   and so gives the useful comparison.
6. Send back `WTF/Account/<ACCOUNT>/SavedVariables/FamilySurface.lua` from each.

One run per client is enough to begin with. Runs accumulate under the build and the character,
so a second character adds rather than overwrites.

## Afterwards

`docs/MIDNIGHT.md` is where the answers go. After every `git merge main`, run
`tools/surface.py --check`; if it says the list is out of date, regenerate it and ask the
client again about whatever is new. Delete this tool when the branch lands, as 5.0.0.
