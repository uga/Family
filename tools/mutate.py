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

**One full run, at the end, on the tree being committed** - not one behind each edit. The working
loop is `--changed`, which answers in about a second, and on a change that touches no file any
recorded mutation names it says so and stops. A full run started behind every intermediate save
is answering about a tree that has already moved on: four of them were queued in four minutes on
2026-09-20 and cost 32 minutes of machine for one useful answer, which is what taught the lock
below to refuse a second run from the same tree rather than queue it. Running it in the
background is for the ten-minute ceiling the calling tool has, not for carrying on meanwhile.

**So the parallelism is here, inside the run**, and its whole purpose is to make waiting
affordable. One case is one gate, the gate is about six seconds, and the cases have nothing to
say to each other - ninety of them serially is nine minutes, which is long enough that somebody
starts doing something else, and that is how the rule above gets broken.

**Nothing here touches the working tree either.** It used to: each case was written into the real
file, gated, and written back. Two things went wrong with that and neither was hypothetical. A
`git add -A` during a run once staged a mutated file. And a run killed part way through left a
mutation standing in `Scanners/Auctions.lua` - the `finally` never reached - so the next gate was
red for a reason that had nothing to do with anything anybody had written. A copy cannot do
either: kill this at any moment and the repository is exactly as it was.

That second episode **is recorded here and nowhere else**, which is worth saying plainly: this
paragraph carried a citation of L-089 until 2026-09-20, and L-089 is *the wait loop matched its
own command line* - a different fault of the same afternoon. Nothing in `LESSONS.md` describes
the mutation left standing. A number that resolves to the wrong lesson is worse than no number,
because it reads as checked; so the number is gone and the account stays.

And it does not sit still. The wrong number had been here since 2026-09-12, and on the day it
was found a reader of this paragraph had already repeated it - citing L-089 for this episode in
a message, from the docstring, without opening the lesson. It had propagated one hop before
anybody checked, which is what a citation that reads as checked does for a living.

    tools/mutate.py                 every case in tools/mutations
    tools/mutate.py one.mut two.mut just those
    tools/mutate.py --changed       cases whose file: - or whose own .mut - is changed or untracked
    tools/mutate.py --jobs 1        one at a time, for when a failure needs watching
    tools/mutate.py --all           print every case, not only the ones that need looking at

**The report names only what needs looking at.** A full run is over two hundred lines and on a
good day every one of them says caught. The reader - a person, or a session whose every later
turn re-reads what once landed in its context - needs the survivors, the moved anchors, the hung
gates and the count; the lines that say caught are what `--all` is for (DECISIONS, 2026-09-14).

**A case's gate is a shorter gate**, asked for 2026-09-13 when a full run took 15 min 25 s on a
twelve-core machine, and brought it to 2 min 52 s the same day (190 cases; 3 min 32 s at 219 cases,
measured 2026-09-14). Each case is gated with `FAMILY_MUTATING=1` in the environment: the harness
stops at its first failure, which is all a case needs to be caught, and skips its second pass
(compression switched off) unless the case file says `pass: both` - the few cases only that pass
can catch. The gate that proves a copy green, and the gate on the repository before anything is
run, are the whole gate. `--changed` is for the working loop; the full run is still the one
required before a commit.

Exit is non-zero if any mutation survived, any anchor has gone, or any gate hung.
"""

import contextlib
import fcntl
import os
import queue
import shutil
import subprocess
import sys
import tempfile
import threading
import time

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

# The files git tracks or would add, written once per run for the harness's sweep of banned
# words: a copy has no `.git` to ask, so the list read here goes to it as `FAMILY_TRACKED`.
TRACKED = None


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
    if TRACKED:
        environment["FAMILY_TRACKED"] = TRACKED
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
        return "the copy's own gate did not finish in %g seconds" % TIMEOUT

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
            # Not caught: nothing was read back, so no check can be said to have seen it.
            # Until 2026-09-14 this answered True, and a hung gate left the exit status green
            # while the docstring promised otherwise (DECISIONS, that day).
            return False, "  HUNG     %s - the gate ran past %g seconds" % (name, TIMEOUT)
        if answered != 0:
            return True, "  caught   %s" % name

        return False, "  SURVIVED %s" % name
    finally:
        # Still restored, even though this is a copy: a worker runs many cases in the one
        # tree, and a case left patched would make every case after it meaningless.
        with open(full, "w", encoding="utf-8") as handle:
            handle.write(held)


def report(results, everything=False):
    """The lines to print for a finished run, and how many cases were not caught.

    In the order they were recorded, whatever order they finished in: a report that shuffles
    itself between runs cannot be compared with the last one.

    A case that was caught is left out unless `everything` is asked for; a survivor, a moved
    anchor and a hung gate are what the run is for, and every one of them fails it.
    """
    lines = []
    bad = 0
    for caught, line in results:
        if not caught:
            bad += 1
        if everything or not caught:
            lines.append(line)
    lines.append("")
    lines.append("%d caught, %d not" % (len(results) - bad, bad))
    return lines, bad


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


def picked(paths, files):
    """The cases a change touches: the file a case mutates, **or the case itself**.

    The second half was missing until 2026-09-20. A `.mut` edited on its own - an anchor
    re-pointed after the code moved under it, a replacement rewritten - names a `file:` that may
    not have changed at all, so the working loop skipped precisely the cases somebody had just
    been working on, and said *no recorded mutation names a file changed* while holding one in
    the diff. Measured by another session over the red full runs of 2026-09-12 to 2026-09-20:
    two of the thirty-three failures were exactly that, a case file changed and its target not.
    """
    return [path for path in paths
            if parse(path)[1] in files or os.path.relpath(path, ROOT) in files]


# One run at a time on this machine, whichever worktree it is started from. Outside every tree
# on purpose: the point is that two *different* checkouts see the same lock.
LOCK = os.path.join(tempfile.gettempdir(), "family-mutate.lock")

# How much of the lock's history to keep. A run writes two or three lines, so this is a couple
# of hundred runs - small enough to leave alone and long enough to read a morning out of.
LOCK_LINES = 500


class AlreadyRunningHere(Exception):
    """A run from this same directory is already going, or already queued behind one."""


def alive(pid):
    """Whether that process is still there. A dead pid in the log is history, not a queue."""
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:                 # somebody else's, and therefore running
        return True
    except OSError:
        return False
    return True


def note(handle, what, extra=""):
    """One line per event, appended. The file is the lock and the lock's own history.

    **Appended rather than rewritten**, which it was for half a day. A file holding only the
    current holder answers *who has it now* and nothing else: on 2026-09-20 a line reading
    `since 15:59:01` was the truth about the run that wrote it and hid the thirteen minutes it
    had spent queued behind two others, and putting those minutes back took the timestamps of
    unrelated files and a transcript. Three lines a run costs nothing and answers afterwards.

    Tab-separated because a path may hold spaces and must not need quoting to be read back.
    """
    handle.write("%s\t%s\t%d\t%s\t%s\n" % (time.strftime("%H:%M:%S"), what, os.getpid(),
                                           os.getcwd(), extra))
    handle.flush()


def standing(text):
    """Every run the log still shows as going, by the log and then by the system.

    The log says what was last written about each process; `alive` says whether that is still
    true. Both are needed: a run killed before its `finally` leaves a *holding* line behind for
    ever, and reading the file alone takes that for a run in progress - which refuses every
    later run from that tree, and names the wrong process to anybody waiting.
    """
    state = {}
    for line in text.split("\n"):
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        when, what, pid, where = parts[0], parts[1], parts[2], parts[3]
        try:
            pid = int(pid)
        except ValueError:
            continue
        if what == "released":
            state.pop(pid, None)
        else:
            state[pid] = (what, when, where)

    return [(pid, what, when, where) for pid, (what, when, where) in sorted(state.items())
            if alive(pid)]


def others_here(text, where):
    """Runs from this same directory that are still going. Ours is not one of them."""
    return [(pid, what, when) for pid, what, when, place in standing(text)
            if place == where and pid != os.getpid()]


def holder(text):
    """Who is holding the lock **now**, which is not the same as who wrote in the file last.

    Read from a live run on 2026-09-20, minutes after the line was written: a session queued
    behind another tree's run was told it was waiting for `pid 3471174 in
    /home/dietpi/dev/Family-retail` - its own earlier run, finished long before, while the lock
    was held by a different process in a different tree. It waited correctly and **blamed the
    wrong directory**, which is the worse half: somebody reading that line goes off to look at
    their own tools, which is the exact journey this whole lock exists to spare them.

    The file cannot say who holds the lock. The lock is the `flock`; the file is what the last
    passer-by wrote in it. So the entries are filtered by whether the process is still there,
    and where none is, this says so rather than name the most recent line.
    """
    live = [entry for entry in standing(text) if entry[1] == "holding"]
    return live[-1] if live else None


@contextlib.contextmanager
def only_one_run():
    """**Two full runs at once do not both go slowly - one of them dies and says nothing.**

    Measured 2026-09-20 on a twelve-thread machine: a run of 396 cases takes about eight
    minutes on its own, and each case's gate is CPU-bound. Two sessions starting a full run
    within a few minutes of each other put sixteen of those gates on twelve threads; both runs
    then go past the ten minutes their caller allows, both are killed, and the output of each
    is lost. That happened four times in two days, and the evidence was four abandoned copies
    of the tree sitting in the temporary directory - killed before the `finally` that removes
    them could run.

    None of that reads as contention from inside either session. It reads as *the mutation run
    has got slow*, which is the wrong thing to go and look at.

    So the second run waits instead, and says whose turn it is while it waits. Waiting is the
    honest outcome: the work is not skipped, and a run that takes sixteen minutes because it
    queued behind another one is sixteen honest minutes rather than two lost ones.

    `--changed` takes it too. The contention is the same contention, and a short run held up by
    a long one is the case this is for.

    **A queue is right between two trees and wrong within one**, which the lock made visible on
    the day it landed. One session made four small edits to two documents and started a full run
    behind each: the lock lined them up and the machine spent 32 minutes on four runs where one
    was wanted. Either the tree has not changed since the run that is going - and the second run
    is the same run again - or it has, and the first run's answer is about a tree nobody has any
    more. Neither is worth eight minutes.

    So a second run **from the same directory** is refused outright rather than queued, and says
    to wait and run once at the end. A run from a different tree still waits, because there the
    queue is exactly right.

    The check is the log and then the system: a run killed before its `finally` leaves a
    *holding* line behind for ever, so a pid that is no longer there is history rather than a
    queue. Two runs started in the same second from one tree can still both get through - the
    look and the write are not one act - which is a second of window against a fault measured in
    half-hours, and it is written down here rather than closed with a second lock.

    **A lock that cannot be taken is announced rather than enforced.** If the file cannot be
    opened at all - another account owns it, the temporary directory is read-only - the run
    goes ahead without it and says so on stderr. Refusing to run at all over that would be a
    worse failure than the one this prevents.
    """
    try:
        handle = open(LOCK, "a+")
    except OSError as trouble:              # noqa: BLE001 - announced, not swallowed
        sys.stderr.write("could not take %s (%s), so two runs can overlap on this machine\n"
                         % (LOCK, trouble))
        sys.stderr.flush()
        yield
        return

    started, took, holding = time.time(), None, False
    try:
        handle.seek(0)
        here = others_here(handle.read(), os.getcwd())
        if here:
            pid, what, when = here[0]
            raise AlreadyRunningHere(
                "a run from this tree is already going (pid %d, %s since %s) - wait for it, "
                "then run once on the tree you mean to commit" % (pid, what, when))

        try:
            fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            note(handle, "waiting")
            handle.seek(0)
            has_it = holder(handle.read())
            sys.stderr.write("waiting for the machine: %s\n" % (
                "pid %d in %s, holding since %s" % (has_it[0], has_it[3], has_it[2])
                if has_it else
                "a run that is not in the log - killed before it could tidy up, most likely"))
            sys.stderr.flush()
            fcntl.flock(handle, fcntl.LOCK_EX)

        trim(handle)
        note(handle, "holding", "waited %ds" % (time.time() - started))
        took, holding = time.time(), True
        yield
    finally:
        try:
            if holding:
                note(handle, "released", "held %ds" % (time.time() - took))
        except OSError:
            pass
        try:
            fcntl.flock(handle, fcntl.LOCK_UN)
        finally:
            handle.close()


def trim(handle):
    """Keep the tail of the log, done while holding the lock so nobody else is appending.

    A line can still be lost if a run happens to be writing its *waiting* line in the same
    instant, which is a line of history and not a lock - the lock is the `flock`, and no amount
    of rewriting this file can take it away from whoever holds it.
    """
    handle.seek(0)
    lines = handle.read().split("\n")
    if len(lines) <= LOCK_LINES:
        return

    handle.seek(0)
    handle.truncate()
    handle.write("\n".join(lines[-LOCK_LINES:]))
    handle.flush()


def main(argv):
    """The run, with the machine to itself. `run_all` is the run."""
    try:
        with only_one_run():
            return run_all(argv)
    except AlreadyRunningHere as why:
        print(why)
        return 1


def run_all(argv):
    jobs = None
    rest = []
    only_changed = False
    everything = False
    argv = list(argv)
    while argv:
        arg = argv.pop(0)
        if arg == "--changed":
            only_changed = True
        elif arg == "--jobs":
            jobs = int(argv.pop(0)) if argv else None
        elif arg.startswith("--jobs="):
            jobs = int(arg.split("=", 1)[1])
        elif arg == "--all":
            everything = True
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
        paths = picked(paths, files)
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

    global TRACKED
    listed = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard"],
                            cwd=ROOT, capture_output=True, text=True)
    if listed.returncode == 0:
        TRACKED = os.path.join(holding, "tracked")
        with open(TRACKED, "w", encoding="utf-8") as handle:
            handle.write(listed.stdout)

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

    progress = sys.stderr.isatty()

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
            # what happened before it had any. Only to a terminal: captured, the carriage
            # returns do not overwrite and the count lands as one line of every step, which
            # is the noise the report just stopped making (DECISIONS, 2026-09-14).
            with counting:
                done[0] += 1
                if progress:
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

    if progress:
        sys.stderr.write("\r          \r")
        sys.stderr.flush()


    lines, bad = report(results, everything)
    for line in lines:
        print(line)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
