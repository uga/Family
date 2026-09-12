#!/usr/bin/env python3
"""Run the recorded mutations and say which ones the gate catches.

A green check proves nothing on its own. What proves it is breaking the code it stands over and
watching it go red - and this project has caught six checks this way in a single evening that
were green and vacuous. But a mutation run by hand vanishes the moment it is run, so a check
that was killed in September is only known to have been killed by whoever remembers.

So they are written down. Each case names a file, a fragment of it, and what to put there
instead; the run patches, gates, restores, and reports.

**A case whose anchor has moved is a failure, not a skip.** That is the whole point of keeping
them: a mutation that no longer applies is a mutation that has quietly stopped testing anything,
which is the same silence every lesson in this repository is about.

    tools/mutate.py                 every case in tools/mutations
    tools/mutate.py one.mut two.mut just those

Exit is non-zero if any mutation survived or any anchor has gone.
"""

import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CASES = os.path.join(ROOT, "tools", "mutations")
GATE = ["lua5.1", "tests/Harness.lua", "."]


def parse(path):
    """A case file: `name:` and `file:` headers, then --- old and --- new blocks."""
    name, target, blocks, current = None, None, {"old": [], "new": []}, None

    with open(path, encoding="utf-8") as handle:
        for line in handle.read().split("\n"):
            if current is None and line.startswith("name:"):
                name = line[5:].strip()
            elif current is None and line.startswith("file:"):
                target = line[5:].strip()
            elif line.rstrip() == "--- old":
                current = "old"
            elif line.rstrip() == "--- new":
                current = "new"
            elif current:
                blocks[current].append(line)

    while blocks["old"] and blocks["old"][-1] == "":
        blocks["old"].pop()
    while blocks["new"] and blocks["new"][-1] == "":
        blocks["new"].pop()

    return name or os.path.basename(path), target, "\n".join(blocks["old"]), \
        "\n".join(blocks["new"])


def gate():
    return subprocess.run(GATE, cwd=ROOT, capture_output=True, text=True).returncode


def run(path):
    name, target, old, new = parse(path)

    if not target or not old:
        print("  BROKEN   %s - no file: or no --- old block" % name)
        return False

    full = os.path.join(ROOT, target)
    if not os.path.exists(full):
        print("  MOVED    %s - %s is not there" % (name, target))
        return False

    with open(full, encoding="utf-8") as handle:
        held = handle.read()

    seen = held.count(old)
    if seen != 1:
        # Not a skip. A mutation matching nothing tests nothing, and one matching twice
        # patches whichever came first, which is not the case anybody wrote down.
        print("  ANCHOR   %s - the fragment appears %d times in %s" % (name, seen, target))
        return False

    try:
        with open(full, "w", encoding="utf-8") as handle:
            handle.write(held.replace(old, new, 1))

        if gate() != 0:
            print("  caught   %s" % name)
            return True

        print("  SURVIVED %s" % name)
        return False
    finally:
        with open(full, "w", encoding="utf-8") as handle:
            handle.write(held)


def main(argv):
    if argv:
        paths = [p if os.path.isabs(p) else os.path.join(ROOT, p) for p in argv]
    else:
        paths = sorted(os.path.join(CASES, f) for f in os.listdir(CASES)
                       if f.endswith(".mut"))

    if not paths:
        print("no mutations recorded in %s" % CASES)
        return 1

    # The gate has to be green first, or every mutation below "catches" something that was
    # already broken and the whole run says nothing.
    if gate() != 0:
        print("the gate is red before any mutation - fix that first")
        return 1

    print("%d mutation(s)" % len(paths))
    bad = 0
    for path in paths:
        if not run(path):
            bad += 1

    print("")
    print("%d caught, %d not" % (len(paths) - bad, bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
