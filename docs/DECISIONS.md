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
| 2026-08-27 | The live check gates releases by tier: three clients recorded for a full release, one row for an alpha or a beta | `SMOKE.md` claimed `RELEASING.md` treated a missing row as a stop, and nothing in the tree had ever heard of the file | `docs/SMOKE.md`, `RELEASING.md` §every time, `tools/release.sh` |
| 2026-08-27 | A whole-family search draws nothing until it is asked, and the caption over its box has to say so | An empty panel under a caption describing the panel's other mode was read as the panel having broken | `Contents.lua`, `Professions.lua` |
| 2026-08-27 | The sides live in `Window.lua`, and every screen that groups by them groups the same three the same way | The summary's copy was the only one, and the gear grid needed the same order and the same two colours | `Window.lua` `UI.SIDE_*`, `Summary.lua`, `Character.lua` |
| 2026-08-27 | The whole family's gear is grouped by side, with a heading each, wherever there are two to tell apart | A row there is nineteen pictures and says nothing else about whose it is; the side was reachable only by hovering | `Character.lua`, `L-011` |
| 2026-08-27 | A borrowed member's *Last seen* reports when they were last shared, marked *shared*, rather than a dash | When they last played does not cross the wire, but when their family last told us does, and the panel already knew it | `Summary.lua` `CELL.seen`, `L-012`-style guard in the harness |
| 2026-08-27 | Wide Family stays off by default now that the live pass has reached it: the reason changes from untested to unasked-for | The 2026-08-12 condition is met, but shipping a sharing feature switched on is a separate decision and not one the pass takes | `MANUAL.md` §11, `About.lua`, `Slash.lua`, `CURSEFORGE.md` |
| 2026-08-27 | The beta.2 pass closes spec §11.0 and `HANDOFF` §4.6 and §4.7; §11.1 stays open and `SMOKE.md` gains the line that can close it | The checklist claimed a completed pass closed all four and had no line testing realm reach, so it closed the three it actually asked about | `Project high level specs.md` §6.0 and §11, `HANDOFF.md` 6 and 7, `SMOKE.md` |
| 2026-08-28 | `tools/Deploy.bat` in the repository is a template with placeholder paths; the real ones live only on the machine that runs it | It carried a LAN address and two install paths into a public repository from the seed commit, and the copy that is run has always been a separate one on the games PC anyway | `tools/Deploy.bat`, harness check *Deploy.bat names no real host* |
| 2026-08-28 | Family is translated into German, French, Spanish and Russian, and the English sentence is the lookup key | The store page had claimed five interface languages since before there was a string table; a key vocabulary of invented names is a second thing to keep in step, and a missing translation should degrade to readable English rather than to a key | `addons/Family/Locale.lua`, `addons/Family/Locales/`, `L-013` |
| 2026-08-28 | Game vocabulary comes from the client's own globals, never from a translation of ours, whatever its length | Blizzard has already decided what a thing is called in German; a shorter word of ours next to the game's own term for it reads as a fault, and a term is not ours to abbreviate | `Family:GameWord`, `Guild.lua`, `Contents.lua`, `Talents.lua` |
| 2026-08-28 | A column too narrow for its heading is widened, and the room is taken from whatever has slack; a column is never put below its own heading | English is the shortest of the five languages and every fixed width in the tree was chosen by looking at it | `UI:FitColumns` in `Window.lua`, `Summary.lua` |
| 2026-08-28 | Counted things are whole clauses chosen by count, never a stem with an `s` hung on the end | Fifteen sites formed their plural by appending a letter; Russian has three plural forms and none of them is that | `Summary.lua`, `Wide.lua`, `Character.lua`, `Talents.lua`, `Contents.lua`, `Quests.lua`, `Broker.lua`, `Guild.lua`, `Slash.lua` |
| 2026-08-28 | `Family:Debug` stays English; `Family:Print` is translated | Narration is off by default and is read by whoever is diagnosing a fault, which is a different reader from the one every other string is written for | `Core.lua`, `Slash.lua` |
| 2026-08-28 | The broker tooltip groups by realm and then by side, splitting only where two sides are actually known | Two members on one realm and opposite sides share no bank, no mailbox and no auction house, and one flat list reads as though they could pass things between them | `Broker.lua`, `Summary.lua` for the shape |
| 2026-08-28 | Buttons size themselves to their own label, and a row is bounded by the room it has | Every button width was chosen by looking at an English label; "Compétence requise" does not fit the 110 pixels "Skill needed" fits, and a row free to grow pushes whatever is beside it off the panel | `UI:LayOutRow`, `UI:FitButton`, `L-014` |
| 2026-08-28 | A row that still cannot fit says so in chat rather than drawing past the panel edge | Squeezing stops at the labels themselves, so overflow is possible and the only bad version of it is the silent one | `UI:LayOutRow`, mirroring the summary's column warning |
| 2026-08-28 | The summary reserves the height its footer and note actually need, measured after they are written | 28 pixels was enough for one line each in English and French wraps both to two, which drew the table's last row underneath them | `Summary.lua`, `GetStringHeight` |
| 2026-08-28 | A race is recorded as id, file string and the recording client's word, and named by the client at display | `raceFile` was being shown raw, so a French client read "NightElf"; by id it is right whoever recorded the member | `Scanners/Identity.lua`, `UI:RaceName` |
| 2026-08-28 | The summary's two profession columns are headed once, and not "Primary" | The secondaries are on the line below, so a column headed Primary was telling the truth about half of what sat under it | `Summary.lua` |
| 2026-08-28 | A caption is given a right edge, or a width, or it is not allowed to hold anything this repository cannot read | A font string with a left anchor and no right one does not wrap - it grows to whatever its sentence is and keeps going past the border | `Options.lua`, `About.lua`, `Contents.lua`, `Guild.lua`, `Wide.lua`, harness *every caption long enough to be a sentence* |
| 2026-08-28 | The guild panel's two buttons are anchored to each other rather than to fixed offsets from the right | `-6` and `-122` encodes "a button that is 110 wide", which was true of the English labels and of nothing else | `Guild.lua` |
