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

## L-018 — A fix shipped on an inference the person with the client then contradicted

**2026-08-28.** A player reported that his bank contents were not being saved and could not say
when. With narration on, his client printed `scanned bank: 56/52 free` — more free slots than
the bank has. That number is certainly wrong, and it is arithmetic over what the client
answered, so one of the three containers open at the time was reporting more free than it had.

From there I reasoned: the free count knows about slots the size call does not, therefore
`GetContainerNumSlots(BANK_CONTAINER)` under-reports, therefore Family reads four slots fewer
than the bank has and anything in them is never recorded. It explained the report exactly. I
changed the scanner to take the larger of the call and `NUM_BANKGENERIC_SLOTS`, wrote a fixture
around it, wrote a lesson about asymmetric costs, and pushed it.

**Alberto then looked at his own client: the Era bank's built-in space is 24 slots.** If that is
so, the size call is right and the fix reports 28 where there are 24 — a wrong total on every
character, to fix a fault I had not established. It is backed out.

The evidence I had was two clients whose *free* counts exceed what their *sizes* allow. That
still needs explaining, and the explanation is not yet known: it may be the size, it may be the
free count covering something other than the container it was asked about. Those want opposite
fixes, which is precisely why one of them should not have been chosen from an armchair.

**What now catches it:** the harness asserts only the thing that is certainly wrong when it
happens — a bank never reports more free slots than it has — and `/family bank` prints, per
container, its size, its free count, and how many of the slots that were read hold something.
That third number is what tells the two hypotheses apart, and it comes from the client.

**The shape.** Earlier the same day I refused to add a retry loop for a recipe fault because the
cause was unproven, and refused an item-id key because no mutation of it could fail. Both were
right. Then a hypothesis arrived that explained the symptom *exactly*, and explaining the
symptom exactly is the most persuasive thing a wrong hypothesis can do. Fit is not evidence. The
person holding the client is.
