# Family — Handoff

This is the document a new session reads first. Family is an alt manager for World of
Warcraft Classic: it records what each of your characters owns and knows, and shows it to
you while you are logged in on a different one. What follows is how it is built and what has
already been decided.

Two companion documents stand behind it.
[`DATASOURCES.md`](DATASOURCES.md) says where Family's facts come from and is authoritative
on data and on everything in `tools/`;
[`Project high level specs.md`](Project%20high%20level%20specs.md) says what Family does and
is authoritative on behaviour.

## Which document answers which question

**Route by the shape of the question, not by how sure the answer feels.**

| The question is about | Read before answering |
|---|---|
| what a version number means, or how a release is cut | [`RELEASING.md`](RELEASING.md) |
| where a fact comes from, or anything in `tools/` | [`DATASOURCES.md`](DATASOURCES.md) |
| what Family does, or should do | [the specification](Project%20high%20level%20specs.md) |
| whether this was already settled | [`DECISIONS.md`](DECISIONS.md) |
| whether this has already gone wrong once | [`LESSONS.md`](LESSONS.md) |
| whether somebody has already asked for this | [`BACKLOG.md`](BACKLOG.md) |

Every one of these exists to override an answer that is plausible in general — a document that
only confirmed the obvious would never have been written. Semantic versioning is the world's
convention and this project deliberately chose another. Asking the client rather than assuming
is good instinct, and this project has drawn a line where it stops. So each document is sited
exactly where the general answer feels strongest, which makes **a fluent answer the signal to
open the file rather than permission to skip it**.

Two ways past this table, both of which have been taken (L-020, L-021). "Archive, fetch only
when the task is about them" means the task and not the file: a passing question about which
number comes next *is* a question about releasing. And a number that can be counted is counted
— a round one chosen because it sounded ample is a guess wearing a fact's clothes.

---

## 1. Architecture — where "more efficient" actually is

These are targets for Family, decided up front.

**Two addons.** A data layer split across many addons exists in order to serve other
people's addons. Family has exactly one client — itself. So:

    Family        data: scanning, storage, sharing
    Family_UI     everything the player sees

Modules are files and namespaces inside those two, not separate addons. There is no
framework and no module-registration plumbing to write.

**One SavedVariables, with a schema version and a real migration path.** Not a format that
silently breaks between versions.

**Lazy, compressed storage.** Character records are stored serialized and compressed
(LibSerialize + LibDeflate) and decoded **on demand**, for the character actually being
looked at. On an account with forty alts, parsing every record at every login is the single
largest cost there is, and nearly all of it is spent on characters nobody is about to look
at.

**An index, not a scan.** Search builds an inverted index once and invalidates it per
character when that character changes. Query cost stops growing with the number of alts.

**Sharing keyed by name, and versioned.** The account-sharing payload identifies each table
by name and carries a schema version, so two players on different versions degrade to
"I can't read that table" rather than to silent data corruption.

**UI in plain Lua with mixins.** No XML frame definitions and no UI framework. Blizzard's
own templates, textures and the `Interface\Icons\` set do the visual heavy lifting.

---

## 2. Naming and conventions

Fixed now, because these end up in every global, folder and saved variable:

- Addon and project name: **Family**
- Folders: `addons/Family/`, `addons/Family_UI/`
- Saved variables: `FamilyDB` (single, versioned)
- Global namespace: a single `Family` table; no other globals
- Slash commands: `/family`, with `/fam` as the short form
- Repository language is **English** — code, comments, commit messages, documents.
  Commit style: a short imperative title, a blank line, then prose in full sentences
  explaining *why*, wrapped at about 90 columns.
- Licence: **GPL-3.0-or-later**. Every `.toc` carries `## X-License: GPL-3.0-or-later`, and
  every source file we write opens with the short GPL notice:

      -- Family - an alt manager for World of Warcraft Classic
      -- Copyright (C) 2026 Alberto Pittaluga
      --
      -- This program is free software: you can redistribute it and/or modify it under the
      -- terms of the GNU General Public License as published by the Free Software
      -- Foundation, either version 3 of the License, or (at your option) any later version.
      -- See the LICENSE file at the root of this repository.

  Third-party libraries are fetched from their own upstreams rather than vendored, and are
  left exactly as their authors shipped them, notices included, without Family's header.
  `LibStub`, `LibSerialize` and `LibDeflate` arrive at package time and their notices travel
  with them.

---

## 3. Repository layout

    Family/
      LICENSE            GNU GPL v3, verbatim
      README.md
      addons/
        Family/          data layer          (to be created)
        Family_UI/       presentation        (to be created)
      docs/
        HANDOFF.md                     this file — what Family is, and how it is built
        DATASOURCES.md                 where the data comes from
        Project high level specs.md    the specification
      tests/
        Harness.lua        loads the addon outside the game and drives it
      tools/             the generators and the deploy script
        FamilyIconSheet/   a development addon: the icon contact sheet (never released)

**Generated data is never committed, only regenerated.** A generator's output can be rebuilt
from the client's own tables whenever it is wanted, so the repository holds the generator
rather than what it produced. The exception is what Family generates from nothing but its
own source — `addons/Family_UI/Textures/Family.tga`, drawn by `tools/GenerateIcon.py` —
which belongs in the tree like any other file, because a shipped addon cannot regenerate its
own artwork on the way out of a zip.

### Running the addon outside the game

    lua5.1 tests/Harness.lua .

It stubs enough of the client to load both addons, fire a login, run a bag scan and refresh
the summary, then checks what landed in `FamilyDB`. It does not prove anything about how a
frame looks, and it cannot know whether an API really returns what it claims — for that the
addon has to go in the game. What it does prove is that the logic holds together, which is
otherwise a relog per guess.

It is worth extending with every slice. It has already paid for itself once, catching the
capability probe silently disabling dual specialisation on Era.

**And it has now failed to pay once, in a way worth learning from.** Family had never received
an addon message — the handler took the event's first value where the dispatcher passes the
event's name, so every message was dropped on the handler's first line. Wide Family and Guild
share both appeared to have faults of their own for weeks; both were this.

Five hundred checks missed it because every one of them called `Comm:Receive` directly. The
transport was covered in detail, and the single line joining it to the game was covered not at
all. **The seam between our code and the client is exactly where a harness stops helping**, and
it is where a check earns the most: fire the real event through the real dispatcher, rather
than calling the thing the dispatcher would have called. Worth auditing for elsewhere — every
`RegisterEvent` handler that reads arguments is the same shape of risk, and the convention that
makes it visible is that they all open with `_`.

The same shape of gap, found the same week: **a button that draws is not a button that can be
clicked**. Every action on the Wide Family panel was dead because the row underneath it was
taking the click, and the harness had five hundred checks that drove panels by calling
`__scripts.OnClick` directly — which answers *does this button have a handler*, never *would a
click reach it*. Two questions, and only the easy one was being asked.

Overlapping frames are settled by strata, then by frame level, then by creation order — and
creation order is the one nobody chooses on purpose. Family's panels build rows, tick boxes and
buttons from separate pools that grow as the screen needs them, so the tie-break was whatever
sequence of screens the player happened to have walked through. **Anything laid on top of a
full-width row says its level outright**, and rows with no handler call `EnableMouse(false)` so
they neither take the click nor offer a highlight that leads nowhere.

`tests/Harness.lua` now models frame levels — `SetFrameLevel` was a no-op stub for the life of
the file — and `reachable(button)` asks the second question. Its structural rule is that a
templated widget sharing a parent with a clickable, untemplated Button must sit at a strictly
higher level, which is checked of every shown button on every panel rather than only of the
one where the fault was found.

### Textures: the one thing that cannot be probed

Every optional API in Family is checked with `type(_G[name]) == "function"` and its answer
read back. Textures get none of that. A path that does not exist draws nothing, or the
client's green placeholder, and `GetTexture()` echoes back whatever string it was handed — so
from inside the client a correct path and a typo are indistinguishable, and the three clients
do not agree on which paths exist. Achievement-era art is the usual casualty on Era.

So a stock icon does not go into Family on anybody's confidence. It goes in after it has been
looked at, on each client, in the **icon contact sheet**:

    tools/Deploy.bat /icons        copies tools/FamilyIconSheet/ alongside the two addons
    /iconsheet                     opens it in the game

It draws every candidate at 32 and at the 18 a tab icon really is, on a backing colour that
cycles magenta / black / white, with a control group whose first cell is a path invented to
be wrong — so a miss can be recognised by comparison rather than by assumption. Clicking a
cell records a choice that survives a reload; *Print chosen* writes them to chat, grouped and
quoted, ready to paste. The last section is not a contact sheet but a measurement: eight real
`136x24` buttons with the real labels and 22 pixels taken off the front for an icon, with the
client asked how wide the text actually came out.

The tool itself is covered by `tests/Harness.lua` — that it builds, draws what it lists, and
that a click reaches the fit test. Whether a path *exists* is exactly what no harness can
answer, which is why the tool exists.

Screenshots belong in `docs/images/icons-<client>.png`. Three of them settle the question for
good; without them the decision is a guess wearing a table.

**Done once, 2026-08-25.** The sheet was run on all three clients and the tab strip, the
Character panel's section buttons and the summary's side filter now carry pictures. Where the
chosen paths live, and the rule about each:

| Table | What it covers |
|---|---|
| `Family_UI/Window.lua` — `TAB_ICONS` | the tab strip. No two may be alike, and the harness checks it |
| `Family_UI/Character.lua` — `SECTION_ICONS` | all five sections of the Character panel. Achievements uses achievement-era art, which Era may lack and which cannot matter: that button is not built on a client with no achievements |
| `Family_UI/Summary.lua` — `FACTION_BANNER` | the two side filters, which were the letters `A` and `H` until there was art that had been looked at |

They are **tables rather than paths written where they are used**, and that is the point: the
set of paths Family asserts exist is then one thing to audit against one set of screenshots,
rather than a dozen string literals scattered across a dozen files with nothing tying any of
them to the day somebody checked. The harness holds all of it to one rule it can check without
eyes: **no two entries, in either table, may be the same path.** Two rows drawing one picture
has stopped being readable by picture, which is most of what the pictures are for, and it is
the mistake that actually happened — Summary and Wide Family were first given the same one. Adding a picture anywhere in Family means adding a row to
one of these, and running the sheet again first.

Two consequences worth knowing. The **window grew from 900 to 924 pixels** and the tab strip
**from 136 to 160** so that putting
a picture in front of every label cost no label any room — sized down instead, "Abilities &
Talents" would have been the one to go, and a tab whose name is cut in half says less than a
tab with no picture on it. The window grew by exactly what the strip took, because the strip
takes its width out of every panel's content and the summary said so at once - the side filters
at the right-hand end of its top row began touching the last set button. And
`tools/FamilyIconSheet` carries the strip's width in `TAB_W`: keep the two in step, or its fit
test measures a tab strip that does not exist.

The Professions panel is the exception to all of this, and it is the better pattern where it
can be had: a profession's picture arrives from `GetProfessionInfo` beside its rank, so it is
the client's own answer, right in every language, and never a path Family asserted. Where the
client has no such call the button keeps its centred label. **Ask the client first, and reach
for these tables only when it will not say** - the same rule
[`DATASOURCES.md`](DATASOURCES.md) §1 states for names.

The screenshots themselves were never kept. That is a gap: the decision is recorded but the
evidence for it is not, so the next person to doubt a path has to run the sheet again rather
than look. Cheap to fix the next time somebody has all three clients open.

---

## 4. Open decisions

1. **GitHub repository.** Private for now. Public at first release, with the history intact
   and never squashed.
2. **A logo.** The one visual asset that cannot be generated here.
3. ~~**Rewriting the deploy script.**~~ **Done 2026-08-08: `tools/Deploy.bat`.** Written
   from scratch for Family's two folders. What it carries over is the three real game paths,
   which are the only part that was ever specific to this machine. It names the two folders
   explicitly instead of matching a pattern, and refuses to point a mirroring copy at
   anything that does not end in `Interface\AddOns`. Since 2026-09-05 it also writes the same
   two folders into a Google Drive folder ending in `Addons`, on a route of its own with a
   guard of its own — a client's guard is about clients, and a second route without one would
   be a mirroring delete aimed wherever a placeholder happened to point. `/nodrive` skips it,
   and the committed path is a placeholder like the other three.
4. **Where the generators write.** Their `--out` defaults must be repointed once
   `addons/Family/` has a data folder and it is named.
5. **The presentation pass, deliberately deferred.** Decided 2026-08-08: the panels are
   built for correctness first and looked at properly in one pass later, rather than
   polished piecemeal as each slice lands. What is knowingly outstanding:

   - **The member picker is two arrows, not a list. Do this one first.** The specification
     (§4.3) says a searchable list, precisely because forty members do not fit in a row of
     icons - and they do not fit behind a pair of arrows either. Reaching the fortieth
     member currently means thirty-nine clicks, which is not a rough edge but a wall.
     The talent panel is the first screen to need it and plainly not the last, so it
     becomes a shared control rather than being solved twice - and every panel from here
     on assumes it exists.
   - **The window is a fixed 900x560 and cannot be resized.** This is the real reason a
     53 point talent tree overflows.
   - **The talent comparison is a flat list, not a grid.** It reads accurately, and it does
     not look like a talent tree. Tier and column are recorded, so the data for a grid is
     already there. **Decided 2026-08-08: when it is done, it copies Blizzard's own talent
     pane layout** - two trees drawn as the game draws them, side by side - and hovering a
     talent shows its tooltip, as the game does. Nobody has to learn a second way of
     reading a talent tree, and the comparison is then the only thing the panel adds.
   - **Icons are 12px, sized to the text line.** Confirmed correct and legible in game; a
     grid layout would want them at 24 or 32.

   None of these is a defect in what the panels report, which is why they wait. The order
   above is roughly the order of how much they matter.

6. **Whether Guild share ships switched on.** Added 2026-08-12, and it is the same shape as
   the Wide Family question without being the same question. It is specified as on by default
   (specification §7) and is built that way, on the argument that everything it carries —
   class, level, gear, both talent trees — is what the game already gives any guildmate who
   presses Inspect, so a consent dialogue in front of it teaches people to click through
   consent dialogues and costs specification §6's grid its meaning.

   That argument holds and is still why Guild share has no consent grid. The narrower
   question — that nothing in it had crossed a real server — was settled on 2026-08-27 by the
   1.0.0-beta.2 pass, on all three clients.

   **Decided on 2026-08-28: it ships off.** Not because consent requires it, but because a
   first release should not begin talking to a guild on somebody's behalf before they have
   asked, whatever it is saying. What the argument above buys is that turning it on needs no
   dialogue and no grid — one switch, on a panel that is in the list whether the feature is on
   or off. The same reasoning put Wide Family's panel there too.

7. **Verifying the API guesses against a real client.** `Capabilities.lua`'s probes, the
   `C_Container` fallbacks in `Scanners/Bags.lua`, and the multi-value `## Interface:` line
   in both `.toc` files were written where the game cannot be run. `/family caps` reports
   which capabilities were confirmed by the client and which Family is assuming, and that
   report is the first thing to look at in game.

   **Settled as of 2026-08-27.** The capabilities section is the first thing `SMOKE.md` asks
   for and it passed on Era, Anniversary and Mists across both the beta.1 and beta.2 passes:
   `/family caps` runs, everything it reports as confirmed the client really has, and nothing
   it reports as assumed is wrong. The multi-value `## Interface:` line is accepted on all
   three — the packager built and uploaded for 1.15.9, 2.5.6 and 5.5.4 from it. This entry
   stays as the description of how to check it, which is a thing every future client needs.
