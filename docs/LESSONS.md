# Family — lessons

Mistakes that cost real time, and the check that now catches each one. A lesson enters as an
observation; it is promoted once a check exists that catches it, whatever the bite count — a
lesson a check enforces is enforced, and one without it is not. The ratchet only turns one way.

An entry naming no check is the useful signal in this file: it means the lesson is still being
held in somebody's head, which is where the last three went wrong.

---

### L-001 — a capability probe can quietly demote a feature

**Bitten:** the probe disabled dual specialisation on Era, silently, on a client where it
should have been available. Nothing failed; the panel simply offered less.

**Why it was invisible:** a capability that answers "no" looks exactly like a capability that
is genuinely absent. There is no error to notice.

**Caught by:** `tests/Harness.lua` — the harness was written for exactly this and found it
before the game did. Status: **promoted.** Every capability probe gets a check that asserts
the answer per client, not just that the probe runs.

---

### L-002 — a stub that answers everything proves nothing

**Bitten:** the possessions panel drew the keyring as a helm for weeks, with the harness
perfectly content. `SetTexture` went to the same `noop` as everything unrecognised, so no
check could see what anything had been drawn as.

**Why it was invisible:** the checks passed. They passed because they asserted nothing — the
stub answered a function for every key, so a comparison against a string compared against
something that was not one.

**Caught by:** `tests/Harness.lua` now records `__texture` and refuses to answer a function
for any `__`-prefixed field. Status: **promoted.**

---

### L-003 — the harness can still pass vacuously

**Observed, not yet bitten again:** L-002 was fixed for textures specifically. The general
case remains — the frame metatable returns `noop` for any key it does not recognise, so a
panel calling an API nobody stubbed still passes.

**Caught by:** nothing yet. **This is the open one.** The fix is to make unstubbed access
visible: count it, print it at the end of a run, and decide later whether an unstubbed call
should fail the run outright.

---

### L-004 — two documents tracking the same thing will disagree

**Bitten:** `HANDOFF.md` §4 and specification §11 both listed open questions. Three
contradictions accumulated — the import question answered both ways, a deploy script listed
as needing work three months after it was rewritten, and the logo settled in one list and
open in the other.

**Why it was invisible:** each document was internally plausible. Only reading them against
each other showed it, and nothing ever did.

**Caught by:** `docs/DECISIONS.md` is now the single record, and both lists point at it.
Status: **promoted.** A second list of project state is a defect, not an organisational
choice.

---

### L-005 — a handler is not covered until the client fires it

**Bitten:** Family had never received an addon message, on any client, in either direction, for
the whole of the project's life. The `CHAT_MSG_ADDON` handler took the event's first *value*
where the dispatcher passes the event's *name*, so the prefix test compared `CHAT_MSG_ADDON`
against `Family` and dropped every message on the handler's first line. Wide Family and guild
share each appeared to have faults of their own for weeks; both were this one line.

**Why it was invisible:** five hundred checks exercised the addon channel, and every one of
them called `Comm:Receive` directly. The transport was covered in detail and the single line
joining it to the game was covered not at all. The seam between our code and the client is
exactly where a harness stops helping, and it is where a check earns the most.

**Caught by:** `tests/Harness.lua` — "an addon message arriving the way the game delivers it"
sends through `Comm:Send`, then fires `CHAT_MSG_ADDON` through Core's dispatcher exactly as the
client does, and asserts the body, the sender, and that another addon's prefix is still left
alone. Status: **promoted.** An event handler is exercised by firing the event, never by
calling the thing the dispatcher would have called; the convention that makes them findable is
that they all open with `_`.

---

### L-006 — a button that draws is not a button that can be clicked

**Bitten:** every action on the Wide Family panel — Accept, Decline, Ask again, Forget — drew
perfectly and did nothing, because the full-width row underneath was taking the click.
Overlapping frames are settled by strata, then frame level, then creation order, and creation
order was the tie-break here: the rows and the buttons come from separate pools that grow as
the screen needs them, so it was whatever sequence of screens the player had walked through.

**Why it was invisible:** five hundred checks drove panels by calling `__scripts.OnClick`
directly, which answers *does this button have a handler* and never *would a click reach it*.
Two questions, and only the easy one was being asked — helped by `SetFrameLevel` having been a
no-op stub for the life of the harness, so the answer to the hard one was not even modelled.

**Caught by:** `tests/Harness.lua` now models frame levels, and `reachable(button)` asks the
second question structurally: a widget pinned by a single corner is covered if it shares a
parent with a shown, clickable, full-width sibling at the same level or higher. "nothing
anywhere is drawn on a row that would eat its click" applies it to every shown clickable widget
in the frame list rather than only to the panel the fault was found on. Status: **promoted.**
Anything laid on top of a full-width row says its level outright, and a row with no handler
calls `EnableMouse(false)`.

---

### L-007 — a term on a removal list can collide with a client API

**Bitten:** not yet, and that is why it is written down. A sweep of the tree for references to
other people's addons matched a word ten times in `tools/FamilyIconSheet/IconSheet.lua`. Every
one of them was a call in the client's own texture API — the one texture question the client
answers honestly, and what lets the icon sheet say *the client confirmed this one exists*
instead of *look at it*. Nothing belonging to the addon that shares the name was ever in the
file.

**Why it would be invisible:** a case-insensitive grep for a bare word cannot tell an addon's
name from a call in the client's own API, and a sweep that reports zero hits reads as the
safer outcome. Removing those lines would have deleted the one honest answer in the tool and
left the grep green.

**Caught by:** nothing automatic, and by this file's own rule that makes it the entry to worry
about. **A match is a question, not a verdict**: before a term comes out, ask whether the
client answers to that name too. The comment at `tools/FamilyIconSheet/IconSheet.lua` names the
call, at the line a sweep will land on.

---

### L-008 — a file changing under you mid-run is the human working

**Bitten:** three screenshots in `docs/images/` went modified while a long sanitisation pass
was running. Read as a fault — something rewriting the folder on its own — one of them was
swept into a commit, amended back out, reported as suspicious, and then discarded. It was a
person re-taking the picture by hand at the other end of the same working tree. The file
survived only because a copy had been taken before the discard, and the copy was luck rather
than method.

**Why it was invisible:** git records that the bytes differ, never who changed them, and an
unexplained modification in the middle of a run reads as a defect rather than as somebody
working. The tree is shared with a person who is not required to announce edits.

**Caught by:** nothing automatic, and nothing can be — this one is a working rule instead. A
file that changes under a run is the human until they say otherwise. It is never discarded
without asking, it is never swept into a commit it has nothing to do with, and where
discarding it is what was asked for, a copy is taken first and its location is reported.

**Bitten again, 2026-08-27:** the second clause failed, in a session that had read this entry.
Five paths were staged by name — the right five — and `git add` took whatever was in them at
that instant, which included another session's in-flight edits to three of them: a decision
row, a run of checklist items and fifty-eight lines of harness. The commit message described
half its own contents. Nothing was lost and nothing was public, but unpicking it cost a
rebuild of three commits.

Naming the paths is not the protection it looks like. A path is not a diff: between reading a
file and staging it, a shared tree can put anything inside that path, and staging by name
takes the file rather than the work. What holds is comparing the staged diff against the work
actually done — `git diff --cached --stat` against the `git diff --stat` taken before the
edits — and treating any line that does not match as somebody else's until asked.

---

### L-009 — a publish can half-succeed, and the half that worked is the one you cannot undo

**Bitten:** `v1.0.0-beta.1`, the first release. The workflow uploaded the zip to CurseForge,
said `Success!`, and then returned 403 creating the GitHub release: `GITHUB_TOKEN` is
read-only unless a job asks for `contents: write`, and `release.yml` had never asked. The run
went red on a version that was already public on CurseForge.

**Why it was invisible:** every rehearsal of the release path stops at the tag. `release.sh`
refuses on a dirty tree, an existing version, an empty changelog and a red harness, and all
four of those are checks on the *inputs*; nothing exercised the permissions the workflow
would need once it ran. The repository default was read-only, which is the right default and
therefore not something anybody thought to look at.

The shape is the general one: a publish is several steps against several services, they do
not share a transaction, and a failure part-way through leaves the irreversible half done.
Reading the red run as "the release failed" would have been wrong in the direction that
matters — retrying it would have uploaded a second file to CurseForge.

**Caught by:** `tests/Harness.lua` — the last check in the file reads
`.github/workflows/release.yml` and fails unless the job grants `contents: write`. Verified
by deleting the block and watching the harness exit 1, not by reading it. Status:
**promoted.** `release.sh` runs the harness before it tags, so the check stands between the
mistake and the tag rather than after it.

---

### L-010 — a mirroring copy deletes what the source was never going to have

**Bitten:** the first deploy out of the new public checkout removed `Libs\LibStub`,
`Libs\LibSerialize` and `Libs\LibDeflate` from all three clients at once. `addons/Family/Libs`
is gitignored — the three are `.pkgmeta` externals, and only `tools/FetchLibs.sh` puts them in
a working tree — so the fresh clone had no `Libs` at all, and `/MIR` removed the ones the
clients had to make the destination match.

**Why it was invisible:** robocopy reported it, in the sense that a wall of `*EXTRA File`
lines went past — which reads as *files being added* to anyone who has not just been thinking
about mirroring, and reads as nothing at all in a locale where it says `*File supplementare`.
The run then printed `Done. Start the game`, because from the copy's point of view nothing had
gone wrong. Family kept loading afterwards: the three are `## OptionalDeps`, so the only
symptom was Wide Family silently having no channel and storage silently being uncompressed.

The shape is the general one, and it is L-009's shape pointed the other way: the destructive
half of an operation is the half that produces no error. A guard that asks "is the source
what it claims to be" cannot catch this, because the source was entirely valid — it was
missing something the destination had, which is precisely what `/MIR` exists to resolve.

**Caught by:** `tools/Deploy.bat` — it now tests the source for `Libs\LibStub\LibStub.lua`,
names the three libraries in its banner when they are there, and prints a WARNING before the
copy saying the three will be deleted when they are not. It warns rather than refuses, because
deploying without them is how the path a player without them takes gets tested.
`tests/Harness.lua` reads the batch file and fails unless both the test and the warning are
still in it — verified by deleting them and watching the harness exit 1, then restoring and
watching it pass. Status: **promoted.**

---

### L-011 — a harness that loads a panel twice has two of that panel

**Bitten:** a new check on the whole family's gear, asserting that a family with characters on
both sides is split into them. The check set two members' sides, called `Family.UI:Refresh()`
and read the screen. It failed. `Family.Database:Meta` said each member had the side it had
just been given, the panel's own status line said *3 of 3 members*, and the grid was plainly
drawn — so the time went into the drawing code, which was right all along.

**Why it was invisible:** `tests/Harness.lua` loads `addons/Family_UI/Character.lua` a second
time on purpose, to put a client that has achievements in front of the achievements branch —
and says so, in a comment, at the place it does it. What it does not say is the consequence:
`UI:RegisterTab` appends without asking whether the id is taken, so there are then two tabs
called `character`. `ShowTab` builds both and leaves `current` on the second; `clickButton`
walks the frame list in the order it was built and drives the first. The clicks and the
refresh were working on two different instances of the same panel, each internally consistent,
neither of them wrong. Nothing in the output could have said so: the status line being read
was the one the *clicks* had drawn, and it was accurate about the draw it came from.

The shape: when a check reads state that some other call is supposed to have changed, it is
only a check if both ends address the same object. "It says the right thing" and "it says the
right thing about what I just did" are different claims.

**Caught by:** `tests/Harness.lua` now counts the tabs answering to `character` immediately
after the second load and fails unless there are two of them, with the consequence written
beside the count rather than left to be rediscovered. The check that needed it drives the
panel by clicking — two clicks on *Whole family*, which leave the mode where they found it and
draw it twice on the way — rather than by asking for a refresh. Verified the check is real by
setting the heading's condition to `false` and watching it fail, then restoring it and watching
it pass. Status: **promoted.**

---

### L-012 — a rule that names its own enforcer, and is enforced by nobody

**Bitten:** `docs/SMOKE.md` said in bold that a release with no row in it was a release that
was not checked, and that `docs/RELEASING.md` treated that as a stop. `RELEASING.md` had never
heard of the file. Neither had `release.sh`, `DECISIONS.md`, the harness or the changelog: the
string `SMOKE` appeared nowhere in the tree outside the filename. `v1.0.0-beta.1` was tagged
and published against a rule that read as mandatory and was mandatory on nobody.

**Why it was invisible:** the sentence names an enforcer, and naming one reads exactly like
having one. Every reader of `SMOKE.md` — including the sessions that wrote and revised it —
took "`RELEASING.md` treats that as a stop" as the record of a mechanism rather than as a
claim about another file, because that is what such a sentence normally is. The file was
never wrong about what *should* happen, so nothing it said could be caught by reading it. Only
the other document, which stayed silent, could have contradicted it, and silence is not
something a reader goes looking for.

The shape is general and this file is where it will recur: a document that says another
document, script or job enforces something is making a testable claim about a second file. It
is worth exactly as much as that second file, and it decays the moment either is edited alone.

**Caught by:** `tools/release.sh` now refuses to tag a version with no row for it, and
`tests/Harness.lua` reads `release.sh` for that refusal and reads `RELEASING.md` for the name
of the file it enforces — so the claim and the mechanism fail together or not at all. Verified
by deleting the refusal and watching the harness exit 1, and by running the gate against an
empty table, a one-client table and a three-client one. Because `release.sh` runs the harness
before it tags, the gate stands in front of its own removal. Status: **promoted.**

---

### L-013 — a capability claimed in a document and built by nobody

The store page said *"English, German, French, Spanish and Russian, for both the interface
and the recorded data."* The data half was true and is true by construction — identifiers are
language-neutral (§2.1). The interface half had never existed. There was no string table, no
`GetLocale()` call anywhere in the tree, and 490 English sentences hard-coded into the
panels.

Nobody lied. The specification's §8 says the interface half is *"ordinary translation work:
one string table per language"* — a sentence describing a job, sitting under a heading that
opens *"Family fully supports every language Blizzard ships a Classic client in."* The two
halves were welded into one sentence on the store page, and the true half carried the false
one past every reading, mine included.

It was found by a user, not by us: a French player reported that Family showed up in English,
and the answer was that it always had.

**This is L-012 again with the subject changed.** That one was a rule written in one document
and enforced by nobody. This is a capability written in one document and built by nobody. The
shape is identical — a document asserting something about the tree, and nothing anywhere
comparing the two.

**The check that now catches it:** the harness reads the language list out of
`docs/CURSEFORGE.md` and `Project high level specs.md` §8, and refuses any language claimed
there that has no file in `addons/Family/Locales/` carrying translations. A document may not
claim a language the tree cannot produce.

Three further checks guard the translations themselves, and each was mutation-tested when it
was written: keys nothing asks for any more, translations too long for the space they sit in,
and format specifiers that do not match their English. The third is not cosmetic — a `"%d of
%d"` translated with one `%d` does not look wrong, it raises inside `string.format` and takes
the panel down mid-draw, for exactly the players who cannot be asked to run a harness.

---

### L-014 — a bulk edit covers the call sites you thought of, not the ones that exist

Wrapping 490 strings for translation was done with a handful of patterns: `SetText`,
`SetFormattedText`, `Print`, `AddLine`, `AddDoubleLine`. They caught 164 sites and the work
looked finished.

They did not catch `return "..."`. Every relative date in Family lives in one — `UI:Ago`,
`UI:In`, and the summary's `duration` are all a chain of `if ... then return "just now" end`
— so a French client showed *"19 days ago"* on every row of every panel while the column
heading above it read *"Vu le"*. It was the most visible untranslated text in the addon and
the pattern list walked straight past it.

The same blind spot hid the button labels. The width budget paired a widget's declared
`SetSize` with the `SetText` it was given, which cannot see a label handed to a helper as an
argument — so `nextButton(label)`, the section rows and the profession sort row were all
unmeasured, and "Compétence requise" was drawn out of its button and into the next one.

**Both were found by a person looking at the screen, not by any check here.**

**What now catches each:** a harness check reads the sources properly - tracking comments and
strings rather than pattern-matching over them, which is what produced the false positives
that made the earlier sweeps easy to wave through - and fails on any literal a player could
read that is not wrapped for translation or named as deliberately internal.

Its first version wanted two words before it would call something a sentence, and passed on
both of the strings a person had just found on screen: "empty" on an unfilled gear slot and
"tier %d" on the talent grid are one word each. The signal that works is the colour code.
Nothing internal is coloured, so `|cff9d9d9dempty|r` is text somebody will read even though
`empty` on its own could be a table key. Three times now a check has been written to the
shape of the reported fault rather than to the fault.

The layout no longer
depends on knowing every label in advance — buttons and columns size themselves to whatever
they are given (`UI:LayOutRow`, `UI:FitColumns`), bounded by the room their row has, and say
so in chat when even that is not enough.

**And a third time, on the same day.** The first version of the caption check looked for
`widget:SetText(L["a sentence"])` and passed cleanly on the Options panel — whose notes are
written `note:SetText(switch.note)`, with the sentences in a table three screens up. It was
checking for the shape of the fault it had been told about rather than for the fault. The
rule that works is the wider one: a caption must be bounded if it is handed a sentence *or*
anything this repository cannot read, because a widget whose contents are not knowable from
here is precisely the one that must not be assumed short.

**The general shape:** a pattern list is a guess about the code, and a guess that returns a
plausible number is the hardest kind to doubt. 164 sites felt like a complete answer. The
check that would have caught it is not a better pattern list - it is not needing one, which
is what sizing to the content actually buys.

---

### L-015 — a name is one language, and the data keyed by it is too

Family stores a profession by its name. That is written down at the top of
`Scanners/Professions.lua` and it is not a mistake: on Era the skill list gives a name and a
rank and no identifier, so there is nothing else to key it by until the client's own SkillLine
table is shipped (DATASOURCES §3).

What was not thought through is that Family now has a reason for the client's language to
change. Two reports arrived within minutes of the same live pass:

- a hunter that had "lost its professions", recovered by reopening each window;
- a **Spanish** panel listing five **French** professions as *never opened*.

Both are the same fault. A member is only re-read when somebody logs in on them, so each
character keeps the language it was last played in - and the recipe lists keep whatever
language *their* window was last opened in, which need not be the same one. When the skill
list and the recipe buckets disagree, nothing matches, and the panel reported the one thing it
could be sure of: no recipes under that name. It said *never opened* about professions whose
recipes it was holding the whole time.

Nothing was lost. Every recipe was still in the database, under a key nobody was looking up.

**The check that now catches it:** the harness sets a member's skills in one locale and their
recipes in another, draws the panel, and fails if it says *never opened* or fails to explain
itself. Records now carry the locale they were written in, which is what makes the two cases
distinguishable without a table of profession names in eleven languages.

**That was the first answer, and it was too small.** It told the player the one thing that
fixed it instead of implying the recipes were never recorded, which is honest, but it accepted
the missing identity as a given. The objection to fixing it properly - that a mapping would
mean shipping profession names in every language - was lifted from the talent-name exception,
where there are thousands of them. There are twelve professions. Sixty short strings is a
paragraph, not a data pipeline, and the objection was never examined once it had been made.

The identity now exists, generated from the client's own `SkillLine` table
(`tools/skill-lines.py`). Both words file under the same number, so nothing needs recovering:
a member recorded in French reads correctly on a Spanish client, and a Wide Family member
shared by a German player files under the same key as everybody else. It also settled a
question the scanner had been answering by heuristic - which professions are primary - because
the same table says so outright.

**And it was the person who could not run the harness who saw the objection was wrong.** The
argument that killed it was "we know the ids from TBC, and no profession was removed" - which
is true, checkable, and was available from the beginning.

**The general shape:** adding a feature can turn a documented, sound trade-off into a live
fault without touching the code that made it. Nothing in `Professions.lua` changed. What
changed is that the language became something a player would move.

--------------------------------------------------------------------------------------------

## L-016 — A check written to the fault, not to the rule

**2026-08-28.** Four faults in one session, all reported from a screenshot, all of a kind.

The activity row said `1 (1 in p...`. The minimap bar said `7658g 65s 19c` while the tooltip
above it said `7656g 25s 04c`. A race recorded on a French client stayed French on a Spanish
one. And the character panel had been reading a race off the record for months.

Every one of them had a check nearby that passed.

- The columns had a check that they *add up to less than the row*. Nothing said a **cell** has
  to fit the column it is put in — a different rule, and only the first was written down.
- Only the overview column set had ever been drawn by the harness. Six of the seven were being
  checked by looking at them in the game, which is a person, on one client, in one language.
- The broker had checks on what its tooltip says. Nothing compared the tooltip to the bar,
  because they were built by the same function and were assumed to agree — and the bar was
  written once at login and never again.
- Changing the two panels that show a race broke no check at all. A check written against one
  panel's output says nothing about the next panel somebody adds.

**The checks that now catch them:** every column set is drawn and every cell measured against
the column it was given; the bar and the tooltip are asserted to say the same sum; and no file
in `Family_UI` may read `meta.race` at all, by name and line number, which is a rule rather
than an instance.

**The shape of it:** a check written to reproduce a reported fault passes as soon as that
fault is fixed, and says nothing about the next one. The rule underneath it — *cells fit*,
*two views of one number agree*, *panels ask rather than answer* — is what has to be written
down, and it is almost always cheaper to check than the instance was.

--------------------------------------------------------------------------------------------

## L-017 — Deciding, for the other end, that it had nothing to learn

**2026-08-28.** A guild panel listing nine guildmates as running Family and a tenth, who
certainly was, as not.

Guild share saves the channel by skipping an exchange when what this client holds from the
announcer is under six hours old. That is sound, and it is what makes "once seen, it is kept"
affordable. What was wrong is that the skip sent *nothing at all* — and being heard from is
the only way one client ever learns that another runs Family.

The assumption underneath it was symmetry: if I have your data, you have mine. It holds right
up until one end's database does not match its history — a player who cleared their saved
variables, or reinstalled, or is testing an unreleased build. Their announcement then reaches
a guild full of clients that each decide, independently and in silence, that there is nothing
to say, and their panel reads every one of them as absent. Nothing recovers on its own,
because every subsequent announcement gets the same silence.

**The check that now catches it:** an announcement from somebody whose record we already hold
must produce exactly one whisper back — one, not the eleven the skip exists to avoid — and the
other client, with no memory of us at all, must learn from that whisper alone that we are here
and must not answer it.

**The shape of it:** an optimisation that decides what to send may not also decide what the
other end already knows. Our own store is evidence about us. It is not evidence about them,
and a protocol that treats it as both fails in exactly one direction, silently, for whichever
end was rebuilt most recently.

**Postscript, the same day.** The check this lesson introduced - every cell measured against
its column - was written to run in English, which is the shortest of the five languages and
the one in which no translated string can possibly fail. Running the same check in all five
took one loop and found six more overflows immediately: a totals label with no translation
short enough to fit the cell it was pinned to, "just now" in three languages, and a Russian
"max level".

Which is this lesson again, one turn later and from the inside: a check written to the shape
of the reported fault. The fault was reported in English, so the check was written in English.

--------------------------------------------------------------------------------------------

## L-018 — A fix shipped on an inference, and the number that was being believed

**2026-08-28.** A player reported bank contents that were not being saved and could not say
when. With narration on his client printed `scanned bank: 56/52 free` — more free slots than
the bank has, which is arithmetic over what the client answered rather than a display fault.

**The first answer was wrong, and it fitted perfectly.** I reasoned that a free count exceeding
the size means the size call under-reports, so Family reads fewer slots than the bank has and
anything in the rest is never recorded. It explained the report exactly. I changed the scanner
to take the larger of the size call and `NUM_BANKGENERIC_SLOTS`, built a fixture around it,
wrote a lesson about asymmetric costs, and pushed it. Alberto then looked at his client: Era's
bank is 24 slots. The fix reported 28 where there are 24, for a fault never established. Backed
out.

**What settled it was making the client answer per container.** With size, free, and how many
of the read slots hold something, printed for each: every bank bag added up — held plus free
equals size, four times over — and only the bank's own window did not. Twenty-four slots,
twenty-four of them holding something, four reported free. And no empty square on screen: the
player looked.

Twenty-eight minus twenty-four is four. The client computes the bank's free count from a size
the bank does not have, and is therefore out by exactly four whatever is in it — full, as here,
or empty, as on the other client where an empty bank reported twenty-eight free of twenty-four.

**The fix is to stop asking.** Every slot is read anyway, so how many are free is the size less
what was found. Derived that way the record cannot contradict itself, which is what `56 of 52`
was. The client is still asked what *kind* of bag it is, because that it answers correctly.

**Where the twenty-eight comes from, and why that is the real lesson.** Alberto named it: the
Era client carries the later expansions' data because Blizzard builds all of these from one
codebase, and Era simply does not enable those four slots. `NUM_BANKGENERIC_SLOTS` says 28
because the file it came from says 28. The bank has 24.

That is the thesis `Capabilities.lua` was written to hold, in the file's own words about
achievements: *the client carrying the call is a fact about the build, not about the game*. The
principle was already written down in this repository, with an example of exactly this shape,
and the fix I shipped read an inherited constant and believed it — in a scanner that never
consults the file that states the rule.

**Three things worth keeping.**

A number that cannot be true is not a display fault to be tidied away. It is the one visible
symptom of something wrong upstream, and the fix is upstream.

A hypothesis that explains the symptom exactly is the most dangerous kind, because explaining
it exactly is what a wrong one does best. Earlier the same day I refused a retry loop and a
search-index key for being unproven, and both refusals were right; this one I talked myself
into. What broke the deadlock was not better reasoning but a diagnostic that made the client
answer per container, and a person who looked at the screen and said there were no empty
squares.

And a constant is not a capability. A symbol present in the client is evidence about which
codebase built it and nothing else — which is true of `NUM_BANKGENERIC_SLOTS` exactly as it is
true of the achievement API on Burning Crusade. Where a number decides what Family reads or
records, it has to come from the running game or be confirmed in it, not from a header the
build happened to inherit.

--------------------------------------------------------------------------------------------

## L-019 — A well-formed record of nothing, written over a real one

**2026-08-28.** A player reported bank contents that were not being saved, and could not
identify the scenario. Neither could I, for most of a day. It was not a write that failed and
not a read that came up short: it was a scan of a bank that was not there, producing a record
that looked perfectly healthy, written over one that was.

Away from a bank the client still answers about the bank container — twenty-four slots, none
of them holding anything. Measured with `/family bank` standing in a city. So a scan running
there builds `{ [-1] = { size = 24, slots = {} } }`, which is not empty, passes the guard that
exists precisely to stop empty records being stored, and replaces five containers and eighty-
three items with one container and none.

**An empty bank with no bank bags is indistinguishable from no bank at all.** There is nothing
in the answer that says which it is, so the contents cannot be interrogated for it. Whether a
window is open is the only thing that separates them, and it has to be tracked.

Two things let a scan run without one. The flag was set by three events and cleared by one, so
a single missed `BANKFRAME_CLOSED` left it set for the rest of the session and every bag update
after that scanned a bank that was not there. And closing the window scanned deliberately, for
one last look — at the moment the client has begun taking the bank down, which is exactly when
it answers with a container and nothing in it.

**What now catches it:** a scan records nothing unless a window is open; only opening one sets
that flag; entering the world clears it, because logging in, zoning and teleporting cannot
happen with a bank open; and closing no longer scans, because everything it was for already
arrives as a bag update while the window is open. The harness scans with no window open, with a
stale flag, and after a slot-changed event with no window, and asserts the record is untouched
each time.

**The shape.** A guard against writing nothing is not a guard against writing something
meaningless. `next(containers)` was doing exactly what it was written to do and the record it
let through was well-formed, plausible, and wrong — and because it was well-formed, every screen
displayed it without complaint. When a record can be built from an absence, the check has to be
on whether the source was there, not on whether the result looks like data.


## L-020 — Asking the client a question the files had already answered

**2026-08-29.** A French player on Burning Crusade reported a hearthstone reading `Ironforge`
where their client says `Forgefer`. The cause was the familiar one — a localised word stored as
though it were identity (L-015) — and the fix was the familiar one, a table generated from the
client's own data the way `Races.lua` and `SkillLines.lua` already are.

I proposed a runtime probe instead. A `/family hearth` command, run in game on three clients, to
find out whether `C_Map.GetAreaInfo` could name an area id, so that Family could ask the client
rather than ship a table.

Two documents in this repository already said not to. `CLAUDE.md` sets the precedence: **the
specification beats everything on behaviour and DATASOURCES beats everything on data.**
`DATASOURCES.md` §3 lists the tables wago.tools serves per build, and the first row of that
table is `AreaTable | ID, AreaName_lang — the area ids`. The answer was named, in the file whose
job is to name it, before the question was asked.

**Two rules, and I reached for the wrong one.** "Ask the client rather than assume" is about
*capability* — what this build can do, where the symbol surface lies and only the running game
knows (L-018). It is not about *data*. What the game calls an area is not a capability; it is a
fact recorded per build and per locale, sitting in a file, identical every time it is read. A
probe cannot answer it better than the source can, and costs a session in game to find out.

The discriminator is one question: **does the answer change depending on which client is
running?** If it does, ask the client. If it is the same fact however you reach it, read it from
DATASOURCES, and the probe is a way of taking longer to be less certain.

**What now catches it:** nothing mechanical, and it is worth saying so rather than inventing a
check that would not have fired. What catches it is the precedence line in `CLAUDE.md` being
read as a routing rule rather than a tie-breaker — data questions go to DATASOURCES first, and
`DATASOURCES.md` §3 gets read before any probe is designed, not after one is proposed.

## L-021 — Fluency read as permission to skip the file

**2026-08-29.** Three times in one session I answered from general knowledge a question this
repository had already answered in writing, each against a different document.

The next version number was going to be `1.0.1`, said twice, because that is what semantic
versioning would call a release of fixes. `RELEASING.md` §Version numbers says minor goes up
for a fix and patch is reserved for an `## Interface` bump alone, and `DECISIONS.md` records
that being settled on 2026-08-26. The answer is `1.1.0`.

A runtime probe was proposed to find out what the game calls an area, when `CLAUDE.md` says
DATASOURCES beats everything on data and `DATASOURCES.md` §3 lists `AreaTable` by name. That is
L-020, and it is here again because it turned out not to be one incident.

The area scan was given a ceiling of 6,000, chosen because it sounded ample. The highest named
area is 16,394; 6,000 would have silently found no id for 11% of Era's areas and 18% of Mists's.
"Measure rather than estimate — if a number can be counted, count it" was already a standing
instruction. A mutation run caught it, not a reading.

**The common cause is not forgetting the documents.** The routing table sits at the top of
`CLAUDE.md` and is in front of every session. What fails is the step between having a question
and opening a file, and that step was gated on feeling uncertain — which is uncorrelated with
whether the answer is written down, and in the worst cases inverted. Semver felt certain. "Ask
the client rather than assume" felt certain. A wrong answer arriving fluently is
indistinguishable from a right one arriving fluently.

**And these documents are, by construction, sited in that blind spot.** Each of them exists to
override an answer that is plausible in general — semantic versioning is the world's convention
and this project deliberately chose another; asking the client is good instinct and this project
has drawn a line where it stops. A document that only confirmed the obvious would never have
been written. So the moments when one is most needed are exactly the moments when it feels least
necessary to open.

**What now catches it:** `HANDOFF.md` — the document a new session reads first — opens with a
routing table keyed on the *shape* of the question rather than on confidence, so the trigger is
topical and does not depend on noticing doubt. It says in terms that a fluent answer is the
signal to open the file rather than permission to skip it, that "archive, fetch only when the
task is about them" refers to the task and not the file, and that a number which can be counted
is counted.

It lives there rather than in `CLAUDE.md` because `CLAUDE.md` is not in the repository: a rule
kept only there protects one machine and no clone. `CLAUDE.md` points at it, and does not carry
a second copy — two copies of a rule drift, which is the same reason the harness has one list of
the interface files rather than two.

## L-022 — A grid of tick boxes nobody could tick, under a check that said they could

The guild crafters grid shipped with thirty-two checks behind it, twelve mutations tried
against them, and not one box in the game would answer a click. What the player saw was the
row underneath lighting up as the cursor crossed it, which is the panel saying out loud where
the click was going.

**What was wrong:** each row on that panel is a `Button` as wide as the list. A `Button` takes
the mouse from the moment it is created, whether or not anything is hooked to its click — the
rows carry only an `OnEnter`/`OnLeave` pair for the hover highlight. The tick boxes were
siblings of those rows at the same frame level, so the row won the hit test and the boxes were
a picture.

**The part worth writing down is not the bug.** The harness already had `coveredBy` and
`reachable`, written for this exact class of fault on the Wide Family panel. They did not fire,
because `coveredBy` asked whether the covering frame had an `OnClick`. A row with a highlight
and no click is invisible to that question and opaque to the mouse, which is the worst possible
combination — the model was built from the one instance that had been found, and the instance
that had been found happened to have an `OnClick`.

The file already says this about itself, a few lines above the function: *"the one rule that was
meant to be checked everywhere was in fact checked in the one place the fault had already been
found."* It was written about the previous version of the same test, and it was still true of
the version that replaced it.

**What now catches it:** `coveredBy` asks `takesMouse` — mouse enabled, and any of the six
mouse scripts, not `OnClick` alone. And the reachability question is no longer asked one widget
at a time: a sweep over every frame the run has drawn checks that **every tick box any panel
draws can actually be clicked**, so a panel written next month is examined without anybody
remembering to examine it. Two more checks hold the cosmetic half — that the grid's own rows do
not light up under the cursor, and that no blank row anywhere answers the mouse.

**And a check that finds the wrong thing is not a check.** The first version of the hover test
matched a row by searching for `Smith`, which also occurs inside `Blacksmithing` and inside the
note naming what could not be offered — it found the note, whose mouse is off for its own
reasons, and passed whatever the panel did. Mutation testing is what said so: removing the line
it was meant to protect changed nothing. A needle that matches a substring of something else is
a needle that will eventually match it.

**And it happened again the same evening, in the same file.** A check that a profession recorded
under a *word* is still offered looked for a box labelled `Herbalism` — and another member of
the fixture has Herbalism, keyed by an id, so it found that box and passed while the code under
test refused the case entirely. Its mutation caught it, as before. Both times the repair was the
same shape: match on something only the intended widget can have. Here that is *being ticked*,
because the check ticks it first.

## L-023 — A field the client answers late, written by a merge that skips nothing said

**First, the attribution, because getting that wrong is its own lesson.** A guildmate showed as
*not running Family* although they had played that day, and the defect below was found while
looking into it — but it was not the cause. That guildmate was another player, not one of this
player's own characters; the two clients had simply not been online together yet, and the row
went green the moment they were. The premise "this is one of their alts" came from a name in an
earlier, unrelated conversation and was never checked. **A report explains a symptom only once
somebody has confirmed what the symptom is about**, and a plausible reading of a screenshot is
not that confirmation.

The defect below is real and was found by reading rather than by the report, which is the only
reason this entry survives its own opening.

**What was wrong:** `Scanners/Identity.lua` wrote `fields.guild = GetGuildInfo("player")` and
moved on. `GetGuildInfo` does not answer for the first few seconds of a session — a fact this
project had already established and written down in `Scanners/Bank.lua`, at length, with a
bounded retry built around it. The identity scan runs two seconds after entering the world and
one second after `PLAYER_GUILD_UPDATE`, and both of those can land inside the gap.

Then the second half: `Database:SetMeta` merges, and its loop is `for name, value in
pairs(fields)`. A nil field is not written as nil — it is **not iterated at all**. So "the
client did not answer" and "do not change this" are the same instruction, and nothing later
fires to correct it. The event that scheduled the scan which missed has already been and gone.

**Why the consequence was out of all proportion to the field.** Everything in §7 is keyed by
the guild a character is *recorded* as being in — `Offering()` and `IsOurs` are the only two
places in the whole addon where a scanned field decides whether a member exists for a feature.
One unwritten string removed a character from guild share entirely while leaving them perfect
everywhere else, which from the player's chair is indistinguishable from the addon being
broken.

**What now catches it:** the two calls are read together and mean three things, not two — named
(record it), in a guild but not yet named (keep what is held, ask again, give up after five),
and in no guild (clear it, because the merge would otherwise leave the last guild there for
ever and go on offering a character to a guild they left). Six checks, and the one that matters
most is aimed at the plausible wrong fix rather than at the old bug: clearing the field on *has
not said yet* is caught by its own mutation.

**The part that is not about guilds.** The answer was already in the tree, in another scanner,
written out in fifteen lines of comment — and the scanner with the larger consequence did the
naive thing. A fact learned about a client is worth grepping for before it is learned again:
`Bank.lua` says *"IsInGuild answers the moment the client loads and GetGuildInfo does not"*, and
that sentence would have been found by searching for the function name.

And the general rule underneath it: **a merging write and an API that can answer nothing are a
silent-failure pair.** Wherever `SetMeta` is handed a field straight from the client, ask what
happens on the scan where the client says nothing — and whether anything will ever run again to
put it right.

**A postscript, from the same evening.** The diagnostic added above went through the guild
roster to decide which characters to name — and the client only lists *offline* guild members
when it has been told to, which is a setting the panel's Online only / Everyone button drives.
The character it was written for was offline. So it could not see the case it existed for, and
it said nothing, which reads exactly like "nothing is wrong".

**A check that cannot see the case it was written for is worse than no check, because it
answers.** The no-guild half was moved off the roster at once.

**And the other two lines were left on it, for a reason that was simply wrong.** "Both are
about a character who is on the roster by definition" — true of the guild, false of
`GetGuildRosterInfo`, which is a *filtered* view of it. The next reading from the live client
came back with the no-guild line working and the other two silent about a character who was
neither in the offering nor short of a guild, which is what a blind spot looks like when only
part of it has been fixed. None of the three questions needs the roster: `Offering()` decides
from our own records, so our own records can say why somebody is not in it. All three now do.

The generalisable form: **when a fault is found in one branch of a function, the sibling
branches are suspects, not bystanders.** Fixing the one that was reported and leaving the two
that share its mechanism is how one bug is paid for twice.

## L-024 — A branch that named the problem in a comment and then returned

Ask two characters of one family to link, accept on the first, and the request to the second
stayed on the Wide Family panel reading *waiting for them to answer* — for ever, about a link
that already existed.

The receiving end was not confused. `onLink` had a branch for exactly this, with a comment
saying what it was:

> *Already linked: treat it as a hello rather than as a request, because a second link request
> from somebody already linked is a client that lost track, not a decision to be asked about
> again.*

It then returned without sending anything, leaving the client that had lost track exactly as
lost. The diagnosis was right, was written down, and was never acted on.

**What makes this its own lesson rather than a missing line.** The comment reads as though the
case is handled, and it is handled *locally* — nothing wrong is recorded on the receiving side,
which is what the branch was written to prevent. The half that is missing is on the other end,
where nobody was looking. A branch that correctly declines to act still owes an answer to
whoever is waiting for one, and the addon channel acknowledges nothing (§11.1), so silence is
never a message.

**What now catches it:** the branch whispers `linked` back, so the asker's existing acceptance
path clears the request. And the same conclusion is reached independently from what this end
already holds — any request addressed to a character of a family we are linked with is dropped
the moment we hear from that character or it arrives in an exchange — so a far end too old to
answer costs nothing. Four checks, one for each half and one that the link is not announced a
second time.

**The generalisable form: when a handler decides not to act, ask what the other end is still
waiting for.** "Ignored harmlessly" is a statement about one side of a wire.

## L-025 — Six checks of a thing nothing was calling

A guildmate ticked a profession, opened its window, and the recipe list never crossed. Both
panels were right, both ends were healthy, and the sending client's own diagnosis read
`messages sent from here: 1`.

**What was wrong:** the grid is not the only thing that changes what a character offers.
Opening a profession's window for the first time gives a ticked profession a recipe list where
it had none; learning one recipe changes a list that was already there. Neither touches a box,
so neither went through the path that announces a change — and the traffic control then did
exactly what it exists to do. Both ends held recent gear and talents, so no exchange happened,
so the new fingerprint never crossed, so the list was never asked for. Every piece behaved
correctly and the feature did nothing.

**The part worth the entry.** The fix was `MarkChanged`, and it came with six checks: nothing
to say means nothing is said, a profession that gains a list has something new to say, the
guild is told, it is not told twice, and so on. Every one of them passed **with the watcher
that calls it deleted**, because every one of them called `MarkChanged` by hand.

**When the bug is "nothing triggers this", a check that pulls the trigger itself proves
nothing.** It tests the mechanism and is silent about the wiring, which is the half that was
broken. The check that earned its place is the one that changes a member's payload, fires the
database's own notification, and waits — touching nothing belonging to guild share at all. It
is the only one of the seven that fails when the watcher is removed.

The same shape appeared twice more the same evening, in `Refresh` and in the *Update now*
button: a mechanism that works, reached by nobody. Worth asking of any fix that adds a
function — **who calls this, and is that in the check?**

## L-026 — A wire designed from the design document, not from the measurements

Guild crafters shared nothing at all on Classic Era except enchanting. Two clients in one
guild, both healthy, both panels correct: `professions ticked: 4, of which 0 have a recipe list
to send`.

**What was wrong:** the wire carried a recipe as its spell id, with the item it makes as an
extra, and dropped anything without a spell. On Classic Era `GetTradeSkillRecipeLink` returns
nothing at all — every recipe there has an item id and no spell — so the wire dropped all of
them. The Craft frame on the same client is the mirror image, answering with an enchant id and
no item, which is why enchanting was the one thing that crossed and made the failure look like
a fault in the guild exchange rather than in what it was carrying.

**All of that was already measured and written down**, in `DATASOURCES.md` §2, *Recipe links,
measured rather than assumed*, with the row dumps and the counts — *"150 leatherworking, 67
cooking and 12 first aid recipes, an item id on every one and a spell id on none"* — and with
the rule spelled out at the end of it: **read every link for every id it might carry, and do
not trust a call's name to say what it returns.**

**I designed the wire from `GUILD-CRAFTERS.md` §4.3, which says "a shared recipe is its
spellID", and never opened `DATASOURCES.md`.** The routing table says DATASOURCES beats
everything on data. A working document's summary of what crosses the wire *is* a claim about
data, and it was written before the measurement existed.

**What now catches it:** four checks over a list with item ids and no spells — that it crosses
at all, that the item rides with it, that the fingerprint moves when only an item does, and
that a row with neither id never reaches disk. And a fifth on the search, because two item-only
recipes keyed by the spell they have not got collapse into one row.

**The general form, and it is L-021 wearing different clothes:** a design document that
summarises a measurement is a copy, and a copy drifts. When a design says what an API returns,
that sentence is the one to go and check — it is exactly the sentence nobody re-derives, because
somebody clearly derived it once.

