# Family — decisions

One line per decision, appended the moment it is taken, never edited and never deleted. If a
decision is reversed, that reversal is a new row; the old one stays, because the record of
having thought otherwise is the useful part.

This file is authoritative on **project state**. `HANDOFF.md` §4 and the specification §11
used to both track it, neither outranked the other, and they drifted in three places — which
is why this file exists and why they now point here instead of keeping their own lists.

Everything above the rule below was back-filled on 2026-08-18 from those two lists. Dates are
the dates the decisions were actually taken; the back-fill is the only thing that happened
later.

| Date | Decision | Why, in one line | Where it landed |
|---|---|---|---|
| 2026-08-08 | No import from any other addon, unconditionally | Everything Family holds, it holds because it watched it happen | spec §9 |
| 2026-08-08 | Licence is GPL-3.0-or-later | Answers the question Family was created by: if the author stops, it stays open | `LICENSE`, every `.toc` |
| 2026-08-08 | Generated data is never committed, only regenerated | The generator and the client's own tables rebuild it whenever it is wanted | `.gitignore`, `tools/` |
| 2026-08-08 | Two addons, not a family of modules | Family has exactly one client — itself | `addons/Family/`, `addons/Family_UI/` |
| 2026-08-08 | Deploy script written from scratch | It mirrors Family's two folders and refuses to point anywhere else | `tools/Deploy.bat` |
| 2026-08-08 | History is never squashed; public at first release | The history is the record of how Family was built | policy |
| 2026-08-08 | Presentation pass deferred to one deliberate sweep | Panels are built for correctness first, polished once | `HANDOFF.md` §4.5 |
| 2026-08-09 | No item library, and no catalogue of where items come from | Family reports what members have and know; it does not advise | spec §2.5 |
| 2026-08-12 | Wide Family ships switched off until a real server has seen it | Nothing in it had crossed a live wire | spec §6.0 |
| 2026-08-12 | The logo is generated | `tools/GenerateIcon.py` draws it | `addons/Family_UI/Textures/Family.tga` |

---

<!-- Append below this line. Newest last. -->

| Date | Decision | Why, in one line | Where it landed |
|---|---|---|---|
| 2026-08-18 | `docs/DECISIONS.md` is the single record of project state | Two lists tracked it, neither outranked the other, and they disagreed in three places | this file |
| 2026-08-26 | A lesson is promoted once a check exists that catches it | A bite count measures luck; a check is what actually enforces the lesson | `LESSONS.md` preamble |
| 2026-08-26 | `sanitised` is a transformation of `workshop`, never a source | New content originating on the derived branch means the two have forked and the rebase has stopped being a transformation | policy |
| 2026-08-26 | The sanitisation rewrites `LESSONS.md` too, not only the three big documents | L-007 names a client API that collides with the removal list, so the public copy has to make the same point without the name | `LESSONS.md` on `sanitised` |
| 2026-08-26 | The public repository is seeded by an orphan commit, not by pushing `sanitised` | Sanitising a tree does not sanitise its history: every removed document would be one `git log -p` away | `git checkout --orphan`, at publication |
| 2026-08-26 | `uga/Family` is the working repository; the workshop repository is retired | Publication was the point at which the two stopped needing to be separate, and one repository cannot drift from itself | this clone's `origin` |
| 2026-08-26 | The `workshop` → sanitised transformation ends with the seed, superseding the three rows above it | With one working repository there is no derived branch to keep in step; those rows record how publication happened, not how work continues | policy |
| 2026-08-26 | The CurseForge key is removed from the retired repository | Both repositories carried `release.yml` and the key, so a stray `v*` tag on the workshop side would have published a zip built from the unsanitised history | repository secrets |
| 2026-08-26 | `major.minor.patch` means: major for a revamp or a new function, minor for fixes including a Blizzard patch that breaks something, patch for a `## Interface` bump alone | `RELEASING.md` said the numbers had to parse but never said what the three of them mean | `RELEASING.md` §version numbers |
| 2026-08-26 | The first release is `1.0.0-beta.1`, and `1.0` commits Family to migrating the saved variables rather than resetting them | `RELEASING.md` had held `1.0` back for exactly this promise; the schema number and its migrations are in place to keep it | `RELEASING.md` §version numbers, `Database.lua` |
| 2026-08-26 | The release job asks for `contents: write` itself, rather than the repository default being raised | Every other workflow stays read-only, and the reason sits in the file that needs it | `.github/workflows/release.yml` |
| 2026-08-26 | A GitHub release the workflow failed to create is made by hand, never by re-running the workflow | The CurseForge upload had already succeeded, and a re-run would have put a second file on the project | `L-009` |
| 2026-08-26 | The CurseForge project description is kept in the repository, not only in the web form | A page the project can be rejected over should be reviewable and diffable like everything else, and the next version should start from what the last one said | `docs/CURSEFORGE.md`, `RELEASING.md` step 1 |
| 2026-08-27 | The retired workshop checkout is renamed `dev/Family-history`, and `Deploy.bat`'s share points at `dev/Family-public` | Both trees hold a complete `addons/`, so a stale share path would have deployed the retired one silently rather than refusing | `tools/Deploy.bat` line 36 |
| 2026-08-27 | `Deploy.bat` warns, rather than refuses, when the source has no `Libs` | Deploying without the libraries is how the no-library path gets tested; deploying without noticing is how three clients lost theirs | `tools/Deploy.bat`, `L-010` |
