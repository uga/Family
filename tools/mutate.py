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

**Wait for it. Do not work beside it.** This is a gate on what has just been written, and a gate
answered after the next thing is built is not a gate - a red result then has no clear place to
restart from. Alberto, 2026-09-12: *che senso ha metterlo in parallelo per andare avanti nel
frattempo? E se quando finisce dice che non andava bene qualcosa, da "dove" ricominci?*

**So the parallelism is here, inside the run**, and its whole purpose is to make waiting
affordable. One case is one gate, the gate is about six seconds, and the cases have nothing to
say to each other - ninety of them serially is nine minutes, which is long enough that somebody
starts doing something else, and that is how the rule above gets broken.

**Nothing here touches the working tree either.** It used to: each case was written into the real
file, gated, and written back. Two things went wrong with that and neither was hypothetical. A
`git add -A` during a run once staged a mutated file. And a run killed part way through left a
mutation standing in `Scanners/Auctions.lua` - the `finally` never reached - so the next gate was
red for a reason that had nothing to do with anything anybody had written (L-089). A copy cannot
do either: kill this at any moment and the repository is exactly as it was.

    tools/mutate.py                 every case in tools/mutations
    tools/mutate.py one.mut two.mut just those
    tools/mutate.py --changed       only cases whose file: is changed since HEAD or not yet tracked
    tools/mutate.py --jobs 1        one at a time, for when a failure needs watching

**A case's gate is a shorter gate**, asked for 2026-09-13 when a full run took 15 min 25 s on a
twelve-core machine. Each case is gated with `FAMILY_MUTATING=1` in the environment: the harness
stops at its first failure, which is all a case needs to be caught, and skips its second pass
(compression switched off) unless the case file says `pass: both` - the few cases only that pass
can catch. The gate that proves a copy green, and the gate on the repository before anything is
run, are the whole gate. `--changed` is for the working loop; the full run is still the one
required before a commit.

Exit is non-zero if any mutation survived, any anchor has gone, or any gate hung.
"""

import os
import queue
import shutil
import subprocess
import sys
import tempfile
import threading

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CASES = os.path.join(ROOT, "tools", "mutations")
GATE = ["lua5.1", "tests/Harness.lua", "."]

# How long one gate may take before it is called hung. The gate is about six seconds; a mutated
# one is slower where it is slower at all, and never by this much. Measured rather than picked:
# raise it if an honest run ever comes near, and do not raise it to make a hang go away.
TIMEOUT = 120

# What is left out of a worker's copy. Everything else comes, because guessing what the gate
# reads is how this went wrong the first time: the copy held `addons` and `tests` only, the
# harness also loads `tools/FamilyIconSheet/IconSheet.lua`, and so every gate in every copy was
# red before a single mutation was applied - which reported all ninety-six as caught. A run that
# cannot fail is worth nothing, and this one was mine.
#
# The caches are the only thing here worth excluding, and only for size: 476 MB of downloaded
# game data against about 10 MB of everything else.
SKIP = ("*-cache", ".git", "__pycache__", "*.pyc")


def parse(path):
    """A case file: `name:`, `file:` and optional `pass:` headers, then --- old and --- new."""
    name, target, blocks, current = None, None, {"old": [], "new": []}, None
    passes = "first"

    with open(path, encoding="utf-8") as handle:
        for line in handle.read().split("\n"):
            if current is None and line.startswith("name:"):
                name = line[5:].strip()
            elif current is None and line.startswith("file:"):
                target = line[5:].strip()
            elif current is None and line.startswith("pass:"):
                passes = line[5:].strip()
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
        "\n".join(blocks["new"]), passes


def gate(where, seconds=None, case=None):
    """The gate, with a clock on it. Answers a return code, or None if it never finished.

    **A mutation can make the harness spin.** Take the bound off a loop, or the exit off a
    walk, and the gate stops being a thing that answers - and a run with no clock on it then
    waits for ever on one case out of ninety. That is not a hypothetical shape: half the
    mutations recorded here remove a guard or a limit.

    A hang is reported as its own outcome rather than folded into either answer. It is *not*
    a survivor - the code plainly broke - and calling it caught would be claiming a check saw
    something when nothing was ever read back.
    """
    # `case` is None for the whole gate, and a case's `pass:` value for the shorter one.
    environment = dict(os.environ)
    environment.pop("FAMILY_MUTATING", None)
    environment.pop("FAMILY_PASSES", None)
    if case is not None:
        environment["FAMILY_MUTATING"] = "1"
        if case == "both":
            environment["FAMILY_PASSES"] = "both"
    try:
        return subprocess.run(GATE, cwd=where, capture_output=True, text=True,
                              timeout=seconds, env=environment).returncode
    except subprocess.TimeoutExpired:
        return None


def copy_tree(into, source=None):
    """The repository, less the downloaded caches, copied for one worker."""
    shutil.copytree(source or ROOT, into, ignore=shutil.ignore_patterns(*SKIP))
    return into


def prove(where):
    """**A copy has to gate green before anything is mutated in it.**

    Every case here works by making the gate go red, so a copy that is red already reports
    every one of them as caught. That is not a hypothetical: the first writing of this copied
    two directories out of the repository, the harness reads a third, and the run came back
    96 of 96 in fourteen seconds. Nothing about the output said so.

    So the copy is gated once, clean, before it is used - and the run stops rather than
    reporting on a tree it has no reason to trust.
    """
    answered = gate(where, TIMEOUT)
    if answered == 0:
        return None

    if answered is None:
        return "the copy's own gate did not finish in %d seconds" % TIMEOUT

    out = subprocess.run(GATE, cwd=where, capture_output=True, text=True)
    tail = (out.stderr or out.stdout or "").strip().split("\n")
    return "the copy's own gate is red before any mutation: %s" % (
        tail[0] if tail else "no output")


def run(path, where):
    """One case, in one worker's copy. Answers (caught, line to print)."""
    name, target, old, new, passes = parse(path)

    if not target or not old:
        return False, "  BROKEN   %s - no file: or no --- old block" % name

    full = os.path.join(where, target)
    if not os.path.exists(full):
        # Said against the repository rather than against the copy, because "not there" is a
        # fact about the project and naming a temporary directory would hide it.
        return False, "  MOVED    %s - %s is not there" % (name, target)

    with open(full, encoding="utf-8") as handle:
        held = handle.read()

    seen = held.count(old)
    if seen != 1:
        # Not a skip. A mutation matching nothing tests nothing, and one matching twice
        # patches whichever came first, which is not the case anybody wrote down.
        return False, "  ANCHOR   %s - the fragment appears %d times in %s" % (
            name, seen, target)

    try:
        with open(full, "w", encoding="utf-8") as handle:
            handle.write(held.replace(old, new, 1))

        answered = gate(where, TIMEOUT, passes)
        if answered is None:
            return True, "  HUNG     %s - the gate ran past %d seconds" % (name, TIMEOUT)
        if answered != 0:
            return True, "  caught   %s" % name

        return False, "  SURVIVED %s" % name
    finally:
        # Still restored, even though this is a copy: a worker runs many cases in the one
        # tree, and a case left patched would make every case after it meaningless.
        with open(full, "w", encoding="utf-8") as handle:
            handle.write(held)


def changed_files():
    """What `git diff --name-only HEAD` names, and every file git does not track yet.

    **The second half was missing, and cost a slice its cases.** A file added in the working tree
    is not in the diff against HEAD, so the cases recorded on `RecipeIndex.lua` while it was being
    written were never picked, and had to be run by name (DECISIONS, 2026-09-13).
    """
    files = set()
    for command in (["git", "diff", "--name-only", "HEAD"],
                    ["git", "ls-files", "--others", "--exclude-standard"]):
        out = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        if out.returncode != 0:
            return None
        files.update(line.strip() for line in out.stdout.split("\n") if line.strip())
    return files


def main(argv):
    jobs = None
    rest = []
    only_changed = False
    argv = list(argv)
    while argv:
        arg = argv.pop(0)
        if arg == "--changed":
            only_changed = True
        elif arg == "--jobs":
            jobs = int(argv.pop(0)) if argv else None
        elif arg.startswith("--jobs="):
            jobs = int(arg.split("=", 1)[1])
        else:
            rest.append(arg)

    if rest:
        paths = [p if os.path.isabs(p) else os.path.join(ROOT, p) for p in rest]
    else:
        paths = sorted(os.path.join(CASES, f) for f in os.listdir(CASES)
                       if f.endswith(".mut"))

    if only_changed:
        files = changed_files()
        if files is None:
            print("git did not say what has changed, so nothing can be picked by it")
            return 1
        paths = [p for p in paths if parse(p)[1] in files]
        if not paths:
            print("no recorded mutation names a file changed since HEAD - the full run is "
                  "still the one before a commit")
            return 0

    if not paths:
        print("no mutations recorded in %s" % CASES)
        return 1

    # The gate has to be green first, or every mutation below "catches" something that was
    # already broken and the whole run says nothing. Run against the repository itself, since
    # this is the one gate of the lot that is about the code as it actually stands.
    #
    # **Beside the first copy's own proving gate, not before it.** Both are whole gates, sixteen
    # seconds each on the machine this was tuned on, and neither needs the other's answer to
    # start; one after the other they were half a minute of every run before any case began.
    # The run still stops on either answer before a case is applied.
    holding = tempfile.mkdtemp(prefix="family-mutate-")
    early = {}

    def prepare():
        try:
            early["first"] = copy_tree(os.path.join(holding, "w0"))
            early["wrong"] = prove(early["first"])
        except Exception as trouble:        # noqa: BLE001 - reported, not swallowed
            early["trouble"] = trouble

    preparing = threading.Thread(target=prepare)
    preparing.start()
    standing = gate(ROOT, TIMEOUT)
    preparing.join()

    if standing is None:
        shutil.rmtree(holding, ignore_errors=True)
        print("the gate did not finish in %d seconds before any mutation was applied - "
              "that is the thing to look at" % TIMEOUT)
        return 1
    if standing != 0:
        shutil.rmtree(holding, ignore_errors=True)
        print("the gate is red before any mutation - fix that first")
        return 1

    if jobs is None:
        # **Eight, not every core, and measured rather than assumed.** Lifting the cap to
        # `os.cpu_count()` was asked for on 2026-09-13 when a full run of 204 cases took 3 min 20 s;
        # on the twelve-thread machine that asked, twelve jobs took 3 min 35 s and 3 min 37 s against
        # 3 min 20 s and 3 min 23 s for eight - slower, since the gate is CPU-bound and the threads
        # are not all cores. DATASOURCES §4 has the readings.
        jobs = min(8, len(paths), os.cpu_count() or 1)
    jobs = max(1, min(jobs, len(paths)))

    print("%d mutation(s), %d at a time" % (len(paths), jobs))
    sys.stdout.flush()

    results = [None] * len(paths)

    if "trouble" in early:
        shutil.rmtree(holding, ignore_errors=True)
        print("the copy could not be made: %s" % early["trouble"])
        return 1
    first, wrong = early["first"], early["wrong"]

    if wrong:
        shutil.rmtree(holding, ignore_errors=True)
        print(wrong)
        print("nothing was run, because a red copy would report every case as caught")
        return 1

    todo = queue.Queue()
    for index, path in enumerate(paths):
        todo.put((index, path))

    done = [0]
    counting = threading.Lock()

    # **Every tree is made before any worker touches one.** They used to be copied inside the
    # workers, from the proved tree - which worker 0 was already patching. A copy taken while a
    # case was standing in that tree carried the mutation in for good, and every case run in it
    # afterwards came back caught whatever the checks did. Found 2026-09-12 when a case that
    # survived three gates by hand was reported caught, and it means every full run between
    # that change and this one said less than it appeared to. Copied from the proved tree, and
    # proved once, still - but only while nothing is writing to it.
    trees = [first]
    try:
        for slot in range(1, jobs):
            trees.append(copy_tree(os.path.join(holding, "w%d" % slot), first))
    except Exception as trouble:            # noqa: BLE001 - reported, not swallowed
        shutil.rmtree(holding, ignore_errors=True)
        print("the copy could not be made: %s" % trouble)
        return 1

    def worker(slot):
        where = trees[slot]

        while True:
            try:
                index, path = todo.get_nowait()
            except queue.Empty:
                return

            results[index] = run(path, where)

            # Progress goes to stderr so that stdout stays the report and nothing else -
            # a run this long with no sign of life is one somebody kills, which is exactly
            # what happened before it had any.
            with counting:
                done[0] += 1
                sys.stderr.write("\r  %d/%d" % (done[0], len(paths)))
                sys.stderr.flush()

    try:
        threads = [threading.Thread(target=worker, args=(slot,)) for slot in range(jobs)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
    finally:
        shutil.rmtree(holding, ignore_errors=True)

    sys.stderr.write("\r          \r")
    sys.stderr.flush()


    # In the order they were recorded, whatever order they finished in: a report that shuffles
    # itself between runs cannot be compared with the last one.
    bad = 0
    for caught, line in results:
        print(line)
        if not caught:
            bad += 1

    print("")
    print("%d caught, %d not" % (len(paths) - bad, bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
