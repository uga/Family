#!/usr/bin/env python3
# Family - an alt manager for World of Warcraft Classic
# Copyright (C) 2026 Alberto Pittaluga
#
# This program is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# See the LICENSE file at the root of this repository.
"""Put the lessons that apply in front of a session, at the moment they apply.

A lesson in `docs/LESSONS.md` was found only by a session that thought to search for it, with the
right words, before acting - and on 2026-10-15 the twenty-eight transcripts on this machine showed
407 greps of that file and not one whole reading. So the lessons are brought instead of fetched:

    as a Claude Code hook   stdin is the hook's JSON, stdout what goes back
    --check                 the gate: exit 1, saying why, unless the three files agree

`docs/LESSONS-INDEX.md` holds one rule per lesson and is loaded at the start of every session.
`docs/LESSONS-TRIGGERS.md` says when each one applies: a glob on the file an edit touches, a
regular expression on a Bash command, words in the prompt or in what an edit writes. On a match
the hook answers with the rules, one line each, and remembers per session what it has said so that
nothing is said twice.

**It never stands in the way.** No permission decision, nothing on stderr, exit 0 whatever happens:
a lesson that cannot be read is a lesson not said, and a broken hook that stopped the work would
cost more than every lesson in the file. Whatever goes wrong is written to the log beside the
session state, outside the tree.

**When it arrives** is measured, not assumed (DECISIONS, 2026-10-15): text a PreToolUse hook hands
back reaches the model with the tool's result, after the edit or the command has happened. That
makes it a review of what was just done. The same rules on `UserPromptSubmit` arrive before any
work, keyed on the words of the request.
"""

import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(os.environ.get("FAMILY_LESSON_ROOT") or Path(__file__).resolve().parent.parent)
STATE = Path(os.environ.get("FAMILY_LESSON_STATE")
             or Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state")
             / "family-lesson-hook")

INDEX = "docs/LESSONS-INDEX.md"
TRIGGERS = "docs/LESSONS-TRIGGERS.md"
LESSONS = "docs/LESSONS.md"

# The most one answer may carry. Claude Code takes ten thousand characters and puts anything past
# that in a file the model sees a preview of; a few lessons are worth reading, and twenty are a wall.
LIMIT = 1500

# Longest rule the index may hold. It is the rule and not the story, and the story is one link away.
RULE_MAX = 160

# State older than this is forgotten. A session is a day at most; a week is generous.
KEEP = 7 * 86400

EDITS = {"Edit", "Write", "NotebookEdit"}

INDEX_LINE = re.compile(r"^- \*\*(L-\d+)\*\* (.+)$")
TRIGGER_LINE = re.compile(r"^- (L-\d+)((?: «[a-z]+: [^»]*»)*)$")
TRIGGER_PART = re.compile(r" «([a-z]+): ([^»]*)»")
HEADING = re.compile(r"(?m)^#{2,3} (L-\d+)\b")


def glob_re(pattern):
    """A glob as a regular expression on a path from the root: `*` stays in one directory, `**`
    crosses any number of them, `?` is one character. Anchored at both ends."""
    out, i = [], 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("^" + "".join(out) + "$")


def read_lessons(root=ROOT):
    """The lessons as one list, in file order: id, rule, and the triggers parsed and compiled.

    Raises on anything it cannot read - the gate wants the reason, and the hook swallows it."""
    rules = []
    for line in (root / INDEX).read_text(encoding="utf-8").splitlines():
        m = INDEX_LINE.match(line)
        if m:
            rules.append((m.group(1), m.group(2)))
        elif line.startswith("- **L-"):
            raise ValueError("%s: a line that is not a lesson: %s" % (INDEX, line))

    triggers = []
    for line in (root / TRIGGERS).read_text(encoding="utf-8").splitlines():
        if not line.startswith("- L-"):
            continue
        m = TRIGGER_LINE.match(line)
        if not m:
            raise ValueError("%s: a line that does not parse: %s" % (TRIGGERS, line))
        parts = {}
        for key, value in TRIGGER_PART.findall(m.group(2)):
            if key not in ("files", "cmd", "words") or key in parts:
                raise ValueError("%s: %s has a %r part it cannot use" % (TRIGGERS, m.group(1), key))
            parts[key] = value
        triggers.append((m.group(1), parts))

    if [i for i, _ in rules] != [i for i, _ in triggers]:
        raise ValueError("%s and %s do not list the same lessons in the same order"
                         % (INDEX, TRIGGERS))

    lessons = []
    for (lesson, rule), (_, parts) in zip(rules, triggers):
        globs = [g.strip() for g in parts.get("files", "").split(",") if g.strip()]
        lessons.append({
            "id": lesson,
            "rule": rule,
            "globs": globs,
            "files": [glob_re(g) for g in globs],
            "cmd": re.compile(parts["cmd"]) if parts.get("cmd") else None,
            "words": re.compile(parts["words"], re.IGNORECASE) if parts.get("words") else None,
        })
    return lessons


def relative(path, cwd):
    """A file path as the triggers name it, from the root of this checkout, or None outside it."""
    p = Path(path)
    if not p.is_absolute():
        p = Path(cwd or os.getcwd()) / p
    try:
        return p.resolve().relative_to(ROOT.resolve()).as_posix()
    except ValueError:
        return None


PATHISH = re.compile(r"""[\w./~-]*[\w-]\.[A-Za-z]{1,5}\b|[\w.-]+/[\w./-]+""")


# A command that changes files: an in-place sed or perl, tee - or a script fed in on a heredoc
# that writes, which is how most edits through the shell are made here. A heredoc that only reads
# - the analysis this workflow runs all day - is not one, or every path it names would fire.
WRITING = re.compile(r"\bsed\b[^|;&]*\s-i|\bperl\b[^|;&]*\s-p?i|\btee\b")
SCRIPT_WRITES = re.compile(r"""open\([^)]*['"][wa]['"]|\.write\(|write_text\(|>\s*[\w./$"'{]""")
# The file after a redirect, which is written whatever the command before it was.
REDIRECT = re.compile(r">>?\s*([^\s;&|>]+)")


def writes(command):
    if WRITING.search(command):
        return True
    return "<<" in command and bool(SCRIPT_WRITES.search(command.split("<<", 1)[1]))


def paths_in(command, cwd):
    """Every word in a command that looks like a path and lands inside this checkout."""
    found = []
    for word in PATHISH.findall(command):
        rel = relative(os.path.expanduser(word), cwd)
        if rel and rel not in found:
            found.append(rel)
    return found


def matches(lessons, event):
    """The lessons this event touches, best first."""
    name = event.get("hook_event_name")
    tool = event.get("tool_name")
    given = event.get("tool_input") or {}
    found = []

    path = text = command = prompt = None
    named = []
    if name == "UserPromptSubmit":
        prompt = event.get("prompt") or ""
    elif tool in EDITS:
        target = given.get("file_path") or given.get("notebook_path")
        path = target and relative(target, event.get("cwd"))
        text = given.get("new_string") or given.get("content") or given.get("new_source") or ""
    elif tool == "Bash":
        command = given.get("command") or ""
        # Edits made through the shell are edits too - a heredoc into python, a sed - so a command
        # that writes has its paths matched like an edit's and its text like what an edit writes.
        # One that only reads or runs - a grep, the harness twenty times a session - matches on
        # `cmd:` alone, or every file lesson would arrive in instalments on commands that change
        # nothing.
        if writes(command):
            text = command
            named = paths_in(command, event.get("cwd"))
        else:
            named = paths_in(" ".join(REDIRECT.findall(command)), event.get("cwd"))

    # Writing the index or the triggers is writing every trigger word there is, and is answered with
    # the lessons about documents rather than with all of them.
    own = (INDEX, TRIGGERS)
    if (path in own) or any(f in own for f in named):
        text = prompt = None

    # The reasons add up. A command or the words being written say *this* outright; a file says
    # *about here* - and `tests/Harness.lua` alone is named by forty lessons, so the one whose
    # words are also in the edit has to come before the thirty-nine that only share the file.
    for order, lesson in enumerate(lessons):
        place = 0
        for target in ([path] if path else []) + (named if command else []):
            for glob, compiled in zip(lesson["globs"], lesson["files"]):
                if compiled.match(target):
                    place = max(place, 0.5 if "**" in glob else 1 if "*" in glob else 2)
        score = place
        if command and lesson["cmd"] and lesson["cmd"].search(command):
            score += 4
        if any(words and lesson["words"] and lesson["words"].search(words)
               for words in (prompt, text)):
            score += 3
        if score:
            found.append((-score, order, lesson))

    return [lesson for _, _, lesson in sorted(found, key=lambda t: t[:2])]


def key(lesson, lessons):
    """L-016 and L-103 each name two lessons, so the id is not enough to remember one by."""
    same = [l for l in lessons if l["id"] == lesson["id"]]
    return "%s#%d" % (lesson["id"], same.index(lesson))


def remember(session, keys):
    """What this session has already been told, with the new keys added. Old sessions forgotten."""
    STATE.mkdir(parents=True, exist_ok=True)
    now = time.time()
    for old in STATE.glob("*.json"):
        try:
            if now - old.stat().st_mtime > KEEP:
                old.unlink()
        except OSError:
            pass
    safe = re.sub(r"[^A-Za-z0-9_-]", "_", session or "none")
    where = STATE / ("%s.json" % safe)
    told = set()
    if where.exists():
        told = set(json.loads(where.read_text(encoding="utf-8")))
    return told, where


def answer(event, lessons):
    """The text to hand back, or None, and the keys it says - given what was said already."""
    told, where = remember(event.get("session_id"), [])
    fresh = [l for l in matches(lessons, event) if key(l, lessons) not in told]
    if not fresh:
        return None

    head = "Lessons from docs/LESSONS.md that apply here (the entry has the story):"
    lines, said, left = [head], [], []
    size = len(head)
    for lesson in fresh:
        line = "%s — %s" % (lesson["id"], lesson["rule"])
        if size + 1 + len(line) <= LIMIT - 60:
            lines.append(line)
            said.append(key(lesson, lessons))
            size += 1 + len(line)
        else:
            left.append(lesson["id"])
    if left:
        lines.append("Also: %s - one line each in docs/LESSONS-INDEX.md." % ", ".join(left))

    told.update(said)
    where.write_text(json.dumps(sorted(told)), encoding="utf-8")
    return "\n".join(lines)


def log(message):
    try:
        STATE.mkdir(parents=True, exist_ok=True)
        with open(STATE / "errors.log", "a", encoding="utf-8") as f:
            f.write("%s %s\n" % (time.strftime("%Y-%m-%d %H:%M:%S"), message))
    except OSError:
        pass


def hook():
    try:
        event = json.load(sys.stdin)
        text = answer(event, read_lessons())
        if text:
            print(json.dumps({"hookSpecificOutput": {
                "hookEventName": event.get("hook_event_name") or "PreToolUse",
                "additionalContext": text}}))
    except Exception as error:  # never in the way, whatever it was
        log("%s: %s" % (type(error).__name__, error))
    return 0


def tracked(root):
    # A copy made by tools/mutate.py has no .git; the run hands over the list it read instead.
    listed = os.environ.get("FAMILY_TRACKED")
    if listed:
        return [line for line in Path(listed).read_text(encoding="utf-8").splitlines() if line]
    out = subprocess.run(["git", "-C", str(root), "ls-files", "--cached", "--others",
                          "--exclude-standard"], capture_output=True, text=True, check=True)
    return [line for line in out.stdout.splitlines() if line]


def check(root=ROOT):
    """The gate. Every reason it is red, one line each, and exit 1; or one line and exit 0."""
    problems = []
    try:
        lessons = read_lessons(root)
    except (OSError, ValueError, re.error) as error:
        print("lessons index: %s" % error)
        return 1

    headings = HEADING.findall((root / LESSONS).read_text(encoding="utf-8"))
    listed = [l["id"] for l in lessons]
    if headings != listed:
        missing = [i for i in headings if headings.count(i) > listed.count(i)]
        extra = [i for i in listed if listed.count(i) > headings.count(i)]
        problems.append("%s and %s disagree: in the lessons and not the index %s, in the index "
                        "and not the lessons %s%s" % (LESSONS, INDEX, sorted(set(missing)) or "-",
                                                      sorted(set(extra)) or "-",
                                                      "" if missing or extra else ", or the order"))

    files = tracked(root)
    for lesson in lessons:
        if len(lesson["rule"]) > RULE_MAX:
            problems.append("%s: the rule is %d characters, more than %d"
                            % (lesson["id"], len(lesson["rule"]), RULE_MAX))
        for glob, compiled in zip(lesson["globs"], lesson["files"]):
            if not any(compiled.match(f) for f in files):
                problems.append("%s: %s matches no file in the tree" % (lesson["id"], glob))

    for problem in problems:
        print("lessons index: %s" % problem)
    if problems:
        return 1
    print("lessons index: %d lessons, every one listed in all three files" % len(lessons))
    return 0


if __name__ == "__main__":
    if sys.argv[1:2] == ["--check"]:
        sys.exit(check(Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT))
    sys.exit(hook())
