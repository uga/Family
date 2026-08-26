# Family

An alt manager for World of Warcraft Classic, written from scratch. Two addons:
`addons/Family/` records, `addons/Family_UI/` shows. Repository language is English.

## Where the truth is

Read by section, on demand. Do not summarise these from memory.

| Document | Authoritative for |
|---|---|
| `docs/HANDOFF.md` | what Family is, how it is built, the decisions already taken |
| `docs/DATASOURCES.md` | where facts come from, and everything in `tools/` |
| `docs/Project high level specs.md` | behaviour — what Family does |
| `docs/DECISIONS.md` | project state: what was decided, when, and where it landed |
| `docs/LESSONS.md` | mistakes already made, and the check that now catches each |
| `docs/MANUAL.md`, `docs/RELEASING.md` | archive — fetch only when the task is about them |

Where two disagree, the table above wins top to bottom, except that DATASOURCES beats
everything on data and the specification beats everything on behaviour.

## Grounding

Family asks the client rather than assuming — by id, with capability probes whose answers are
read back. Sessions ask the file rather than assuming, by the same standard.

Before citing any section number, path, function name or measurement, **read it in this
session.** "I believe HANDOFF says" is a bug. If a read fails or a path has moved, say so and
stop; never substitute a remembered version. Anything recalled from a previous session is
stale until re-read.

## Verification

- `lua5.1 tests/Harness.lua .` — over 600 checks. Extend it with every slice; a check costs a
  minute and a wrong answer in the game costs a relog.
- A claim of "done" names the check that proves it. A grep passing is not "it works".
- "Flake", "pre-existing" and "environmental" next to a failing gate are red flags, not
  explanations.
- `tools/release.sh <version>` is the deploy gate and it refuses rather than guesses.
- Textures cannot be probed — the client echoes back whatever path it was handed. They go
  through `tools/FamilyIconSheet/` and a screenshot, never through confidence.

## Scope

State which files a piece of work may touch before starting it, in full, no wildcards.
Anything outside that list is a stop, not a judgement call. A slice is one domain end to end —
record it, store it, show it — never a horizontal layer.

## Reserved — ask, never decide

Present these as numbered questions with a recommendation, and wait.

1. Licence changes.
2. Adopting a third-party library or a new data source.
3. Rewriting or squashing git history.
4. Making the repository public.
5. Shipping a sharing feature switched on.
6. Pushing a `v*` tag. It publishes to CurseForge and there is no clean unpublish.
7. Deleting anything from the tree.

**Everything else is yours to decide.** Naming, panel layout within a settled approach,
changelog wording, which existing check to extend, and any question the specification or
DATASOURCES already answers. Do not ask about those; being asked about trivia is how a
reserved list stops being read.

## Writing it down

- The changelog's **Unreleased** section is written as each thing lands, not at release time.
- A decision goes into `docs/DECISIONS.md` in the same turn it is taken, or it will not go in.
- A mistake that cost real time goes into `docs/LESSONS.md` with the check that now catches it.
- Commits: short imperative title, blank line, then prose in full sentences saying *why*,
  wrapped at about 90 columns. Never squash.
