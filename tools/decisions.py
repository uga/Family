#!/usr/bin/env python3
# Family - an alt manager for World of Warcraft Classic
# Copyright (C) 2026 Alberto Pittaluga
#
# This program is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# See the LICENSE file at the root of this repository.
"""Read `docs/DECISIONS.md` by decision, and say which ones are still in force.

The file is a million bytes, appended to and never edited, and on 2026-10-15 the transcripts of
this project showed 954 greps of it and not one reading: a decision was found only by a session
that searched for it, and nothing said whether a later row had replaced it. This reads it instead:

    --file <path>     the decisions in force that landed in that file
    --id <id>         one decision, whole
    --grep <regex>    every decision matching, each saying whether it is in force or replaced
    --why             with any of the three, the reasoning and where it landed as well
    --check           the gate: exit 1, saying why, unless every row reads as a decision

**An id is computed, never written into the file** (DECISIONS, 2026-10-15): the date and six hex
of the SHA-1 of the row's own text, `D-2026-09-14-3f9a2c`. Date and position would not hold - eight
dates sit in more than one block, from branch merges, so the next merge would renumber rows - while
a row that is never edited never changes its hash. A row present twice is told apart by order: the
second is `.2`.

A row is a decision, not a line. Three lines carry several decisions joined by a literal `\\n`
written into the file by mistake; they are split there, so each has its own id, and a stray one
ending a line is dropped. A line that holds
one decision is hashed whole, exactly as it stands.

`docs/DECISIONS-SUPERSEDED.md` is the judgement of which decision replaced which, written by hand,
one `- D-old → D-new` line each with its reason. A decision named on the left is no longer in force.
A line ending `(in part)` is an amendment: the old decision stays in force, and every answer that
shows it names the row that changed part of it.

**The rows written after the gate are held to two rules** (DECISIONS, 2026-10-15), and the rows
above `GATE_AFTER` to neither, since they were written before anyone asked:

- A row is at most 1,000 characters, counted over the row as it stands. Until 2026-11-15 a longer
  one is a warning and the gate stays green; from the day after, it is red. The rest of the
  reasoning goes in the commit message. `FAMILY_DECISIONS_TODAY` sets the date for a check.
- A row with revision words - *correction:*, *supersedes*, *the row above*, *retracted* - names the
  id of a row, which must exist, or says `no row replaced` where what it revises was never a row.
  The pair that row makes goes into `docs/DECISIONS-SUPERSEDED.md` in the same commit, by hand:
  only the writer knows whether a row it names was replaced, amended or only cited.
"""

import argparse
import datetime
import hashlib
import os
import re
import sys
from pathlib import Path

ROOT = Path(os.environ.get("FAMILY_DECISIONS_ROOT") or Path(__file__).resolve().parent.parent)

DECISIONS = "docs/DECISIONS.md"
SUPERSEDED = "docs/DECISIONS-SUPERSEDED.md"

ROW = re.compile(r"\| (\d{4}-\d{2}-\d{2}) \|")
# Where a line holds more than one decision: the literal backslash-n before the next row's date.
JOINED = re.compile(r"\\n(?=\| \d{4}-\d{2}-\d{2} \|)")
REPLACED = re.compile(r"^- (D-\d{4}-\d{2}-\d{2}-[0-9a-f]{6}(?:\.\d+)?) → "
                      r"(D-\d{4}-\d{2}-\d{2}-[0-9a-f]{6}(?:\.\d+)?)( \(in part\))?$")
# The last row written before the gate on new rows: everything below it in the file is new. An id
# and not a date, because dates in this file run backwards wherever a branch was merged.
GATE_AFTER = "D-2026-10-15-890482"
ROW_MAX = 1000
WARN_UNTIL = "2026-11-15"
# The phrasings that marked the 47 revising rows recorded in DECISIONS-SUPERSEDED, all of them; the
# broader word list (*no longer*, *replaced*, *override*) finds 214 rows to this one's 127.
REVISES = re.compile(r"row above|rows? (of|from) \d{4}-\d{2}-\d{2}|the \d{4}-\d{2}-\d{2} row|supersed"
                     r"|replaces the|corrects the|correction:"
                     r"|\b(retract\w*|withdraw[sn]?|amends|revers(es|al)|corrects|corrected)\b", re.I)
NAMED = re.compile(r"D-\d{4}-\d{2}-\d{2}-[0-9a-f]{6}(?:\.\d+)?")
NO_ROW = "no row replaced"
TICKED = re.compile(r"`([^`]+)`")
# What follows a path to say which part of it was meant: `:12`, ` §3`, `#anchor`.
QUALIFIED = re.compile(r"[:# §]")


def read_decisions(root=ROOT):
    """Every decision in file order, as a dict: id, date, line, the cells, and where it landed.

    Raises on a row it cannot split into cells - the gate wants the reason."""
    decisions, seen = [], {}
    lines = (root / DECISIONS).read_text(encoding="utf-8").split("\n")
    for number, line in enumerate(lines, 1):
        if not ROW.match(line):
            continue
        for text in JOINED.split(line):
            if text.endswith("\\n"):
                text = text[:-2]
            if not text.endswith(" |"):
                raise ValueError("%s line %d: a row that does not end its last cell" % (DECISIONS, number))
            cells = text[2:-2].split(" | ")
            # Four cells is the table; a fifth is a commit added after Where; three is a row whose
            # reasoning ends by naming where it landed (the Midnight rows of September).
            if len(cells) not in (3, 4, 5):
                raise ValueError("%s line %d: %d cells" % (DECISIONS, number, len(cells)))
            date = ROW.match(text).group(1)
            base = "D-%s-%s" % (date, hashlib.sha1(text.encode("utf-8")).hexdigest()[:6])
            seen[base] = seen.get(base, 0) + 1
            decisions.append({
                "id": base if seen[base] == 1 else "%s.%d" % (base, seen[base]),
                "date": date,
                "line": number,
                "text": text,
                "decision": cells[1],
                "why": cells[2],
                "where": cells[3] if len(cells) > 3 else cells[2],
            })
    return decisions


def read_superseded(root=ROOT):
    """The pairs in file order: old id, new id, and whether only part of the old was changed.
    No file yet means nothing has been replaced."""
    path = root / SUPERSEDED
    if not path.exists():
        return []
    pairs = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = REPLACED.match(line)
        if m:
            pairs.append((m.group(1), m.group(2), bool(m.group(3))))
        elif line.startswith("- D-"):
            raise ValueError("%s: a line that is not a pair: %s" % (SUPERSEDED, line))
    return pairs


def landed_in(decision, path):
    """Whether the decision names this file where it landed: the path between backticks, or a
    folder holding it, or the path followed by what part of it was meant (`tests/Harness.lua:12`).

    A name may leave the start of the path off, as a fifth of them do (`Family_UI/Slash.lua`), and
    still names the file while it keeps a folder; a bare file name does not, because seven of them
    name two files each (`Guild.lua`)."""
    for named in TICKED.findall(decision["where"]):
        named = QUALIFIED.split(named.strip(), 1)[0]
        if named.endswith("/"):
            if path.startswith(named):
                return True
        elif named == path or ("/" in named and path.endswith("/" + named)):
            return True
    return False


def show(decision, why, replaced_by=None, amended_by=()):
    out = "%s — %s" % (decision["id"], decision["decision"])
    if replaced_by:
        out += "  [replaced by %s]" % replaced_by
    if amended_by:
        out += "  [amended by %s]" % ", ".join(amended_by)
    if why:
        out += "\n    Why: %s\n    Where: %s" % (decision["why"], decision["where"])
    return out


def check(root=ROOT):
    """The gate. Every reason it is red, one line each, and exit 1; or one line and exit 0."""
    try:
        decisions = read_decisions(root)
        pairs = read_superseded(root)
    except (OSError, ValueError) as error:
        print("decisions: %s" % error)
        return 1

    problems = []
    order = {d["id"]: i for i, d in enumerate(decisions)}
    replaced = {}
    for old, new, part in pairs:
        missing = [i for i in (old, new) if i not in order]
        if missing:
            problems.append("%s names %s, which no row has" % (SUPERSEDED, " and ".join(missing)))
            continue
        if order[new] <= order[old]:
            problems.append("%s: %s is not below %s, so it cannot have replaced it"
                            % (SUPERSEDED, new, old))
        # Replaced twice is two answers to what is in force; a chain says it once: A → B, B → C.
        if not part and old in replaced:
            problems.append("%s: %s is replaced twice, by %s and by %s"
                            % (SUPERSEDED, old, replaced[old], new))
        if not part:
            replaced.setdefault(old, new)

    warnings = []
    after = [i for i, d in enumerate(decisions) if d["id"] == GATE_AFTER]
    if not after:
        problems.append("no row has the id %s, the last row before the gate, so no row can be "
                        "told new" % GATE_AFTER)
    today = os.environ.get("FAMILY_DECISIONS_TODAY") or datetime.date.today().isoformat()
    for d in decisions[after[0] + 1:] if after else ():
        if len(d["text"]) > ROW_MAX:
            said = "%s is %d characters, over %d; the rest of the reasoning goes in the commit" \
                % (d["id"], len(d["text"]), ROW_MAX)
            if today > WARN_UNTIL:
                problems.append(said)
            else:
                warnings.append(said + " (refused from the day after %s)" % WARN_UNTIL)
        if REVISES.search(d["text"]):
            named = NAMED.findall(d["text"])
            unknown = [i for i in named if i not in order]
            if unknown:
                problems.append("%s names %s, which no row has" % (d["id"], " and ".join(unknown)))
            elif not named and NO_ROW not in d["text"]:
                problems.append("%s revises (%r) and names no id; say `%s` if what it revises "
                                "was never a row" % (d["id"], REVISES.search(d["text"]).group(0), NO_ROW))

    for warning in warnings:
        print("decisions: warning: %s" % warning)
    for problem in problems:
        print("decisions: %s" % problem)
    if problems:
        return 1
    print("decisions: %d decisions, every row read; %d replaced and %d amended, every id a row's"
          % (len(decisions), len(replaced), sum(1 for p in pairs if p[2])))
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    which = parser.add_mutually_exclusive_group(required=True)
    which.add_argument("--file", metavar="PATH")
    which.add_argument("--id", metavar="ID")
    which.add_argument("--grep", metavar="REGEX")
    which.add_argument("--check", action="store_true")
    parser.add_argument("--why", action="store_true")
    args = parser.parse_args(argv)
    if args.check:
        return check()

    decisions = read_decisions()
    replaced, amended = {}, {}
    for old, new, part in read_superseded():
        if part:
            amended.setdefault(old, []).append(new)
        else:
            replaced[old] = new

    if args.id:
        found = [d for d in decisions if d["id"] == args.id]
        if not found:
            print("no decision has the id %s" % args.id)
            return 1
        print(show(found[0], True, replaced.get(args.id), amended.get(args.id, ())))
        return 0

    if args.file:
        path = Path(args.file)
        if path.is_absolute():
            path = path.resolve().relative_to(ROOT)
        found = [d for d in decisions if d["id"] not in replaced and landed_in(d, path.as_posix())]
        for d in found:
            print(show(d, args.why, None, amended.get(d["id"], ())))
        return 0

    pattern = re.compile(args.grep, re.IGNORECASE)
    for d in decisions:
        if pattern.search(d["decision"]) or pattern.search(d["why"]) or pattern.search(d["where"]):
            print(show(d, args.why, replaced.get(d["id"]), amended.get(d["id"], ())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
