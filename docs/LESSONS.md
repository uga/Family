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
