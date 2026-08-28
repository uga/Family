# Family Probe

A throwaway addon that asks one client what it calls each profession. **Not part of Family**
and never shipped with it — it lives in `tools/` for that reason.

## Why

A profession has no identifier on Classic Era. `GetSkillLineInfo` hands back `"Couture"` and a
rank and nothing that says *which* profession that is, so Family keys professions by name — and
a name is one language. That is how a Spanish client came to list five French professions as
*never opened* while holding every one of their recipes (L-015).

The fix is a table mapping each language's names onto one identity. Writing that table from
memory is the kind of confidence this project does not accept: `Erste Hilfe` and `Erstehilfe`
look equally plausible from outside the game and only one of them matches. So the client is
asked, and its answers are the evidence the table gets built from.

The spell and skill-line numbers in `FamilyProbe.lua` are **guesses, deliberately**. The probe
records what each one resolves to, including "nothing", so a wrong number costs a line in a
report rather than a silent fault in a release.

## Running it

1. Copy the `FamilyProbe` folder into `Interface/AddOns/`.
2. Log in. It reports in chat five seconds later; `/familyprobe` runs it again.
3. **Log out** — that is when the client writes the file.
4. Repeat on each client language, and on a few characters per language: the skill list only
   shows professions that character actually has, so coverage comes from several of them.
   Results accumulate; nothing is overwritten.
5. Send back `WTF/Account/<ACCOUNT>/SavedVariables/FamilyProbe.lua`.

A Mists client is worth one login of its own: `GetProfessions` there hands back a name and its
skill line id *together*, which is a verified pair with nothing guessed at all.

## What it collects

- The client's locale and build.
- What each candidate spell id resolves to, per language.
- `PROFESSIONS_COOKING` and its siblings, as a cross-check on the three professions the game
  already names for us.
- Every character's skill list: name, rank, cap, and whether it can be unlearned.

It reads, writes one saved variable, and sends nothing anywhere.

## Afterwards

Delete it. It has no purpose once the table is built, and an addon that outlives its question
is one more thing to keep working.
