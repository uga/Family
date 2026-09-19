#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Lists what Family asks of the client, and writes it where tools/FamilySurface reads it.

Midnight is the first client Family was not written against, and the first question about it
is not what Retail has but what Family *touches*. That is countable, so it is counted rather
than recalled: every global a Family file reads, taken from the compiler's own bytecode
listing (`luac5.1 -l`), which sees exactly the names the code looks up and nothing a comment
mentions.

The listing cannot see three things, so each is gathered its own way:

- **Members of the client's namespaces** - `C_Item.GetItemInfo` is one global read and a
  field. Taken from the bytecode where the field is read off the register the global landed
  in, and from the source for the files that copy a namespace into a local first.
- **Events** - a string handed to `RegisterEvent`, often out of a table. Every upper-case
  string literal is kept and the probe asks the client about each, so the list is generous
  on purpose: a literal that is not an event is refused on every client, and only a refusal
  a Classic client does not also give means anything.
- **Frame templates** - a string handed to `CreateFrame`, kept with the frame type it was
  handed with, because a template built on the wrong type can throw on every client.

    tools/surface.py             write tools/FamilySurface/Surface.lua
    tools/surface.py --check     exit 1 if that file is not what this would write
    tools/surface.py --report ASKED.lua [CONTROL.lua]
                                 what a client answered, from the probe's saved variables,
                                 each name with the Family files that use it; with a
                                 control, only where the two clients differ

Re-run after every `git merge main`: a merge that brings in a new call brings in a new
question for the client.
"""

import collections, glob, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tools", "FamilySurface", "Surface.lua")

# Lua's own library and the handful of Lua-level helpers every client defines in its own
# FrameXML. They are not questions about the game.
LUA = set("""
_G assert error ipairs pairs next pcall xpcall select tonumber tostring type unpack rawget
rawset rawequal setmetatable getmetatable math string table coroutine print loadstring
""".split())


def sources():
    files = glob.glob(os.path.join(ROOT, "addons", "Family*", "**", "*.lua"), recursive=True)
    return sorted(f for f in files if os.sep + "Libs" + os.sep not in f)


def listing(path):
    run = subprocess.run(["luac5.1", "-p", "-l", path], capture_output=True, text=True)
    if run.returncode != 0:
        sys.exit("luac5.1 refused %s:\n%s" % (path, run.stderr))
    return run.stdout.splitlines()


GLOBAL = re.compile(r"\t(GETGLOBAL|SETGLOBAL)\s+(\d+)\s+-?\d+\s*; (\S+)$")
FIELD = re.compile(r"\t(?:GETTABLE|SELF)\s+-?\d+\s+(\d+)\s+-?\d+\s*; \"(\w+)\"$")
NAMESPACE = re.compile(r"^(C_\w+|Enum|TooltipDataProcessor)$")


def uncommented(text):
    text = re.sub(r"--\[(=*)\[.*?\]\1\]", "", text, flags=re.S)
    return re.sub(r"--[^\n]*", "", text)


def measure(uses=None):
    """The four lists. Given a dict, also fills it with each name's files."""
    reads, writes, members, strings, templates = set(), set(), set(), set(), set()
    uses = uses if uses is not None else collections.defaultdict(set)
    for path in sources():
        where = os.path.relpath(path, os.path.join(ROOT, "addons"))
        lines = listing(path)
        for index, line in enumerate(lines):
            found = GLOBAL.search(line)
            if not found:
                continue
            op, register, name = found.groups()
            (reads if op == "GETGLOBAL" else writes).add(name)
            uses[name].add(where)
            if op == "GETGLOBAL" and NAMESPACE.match(name) and index + 1 < len(lines):
                field = FIELD.search(lines[index + 1])
                if field and field.group(1) == register:
                    members.add(name + "." + field.group(2))
                    uses[name + "." + field.group(2)].add(where)

        text = uncommented(open(path, encoding="utf-8").read())
        for space, field in re.findall(r"\b(C_\w+|Enum|TooltipDataProcessor)\.(\w+)", text):
            members.add(space + "." + field)
            uses[space + "." + field].add(where)
        for literal in re.findall(r"[\"']([A-Z][A-Z0-9_]{3,})[\"']", text):
            strings.add(literal)
            uses[literal].add(where)
        for kind, template in re.findall(
                r"CreateFrame\(\s*[\"'](\w+)[\"'][^)]*?[\"'](\w*Template\w*)[\"']", text):
            templates.add(kind + ":" + template)

    globals_ = sorted(reads - writes - LUA)
    return globals_, sorted(members), sorted(strings), sorted(templates)


def lua_list(name, values):
    body = "".join('\t"%s",\n' % value for value in values)
    return "Surface.%s = {\n%s}\n" % (name, body)


def render():
    globals_, members, strings, templates = measure()
    return (
        "-- Generated by tools/surface.py from the Family sources. Do not edit: re-run it.\n"
        "--\n"
        "-- %d globals, %d namespace members, %d upper-case literals, %d frame templates.\n"
        "\n"
        "local _, Surface = ...\n"
        "\n" % (len(globals_), len(members), len(strings), len(templates))
        + lua_list("globals", globals_) + "\n"
        + lua_list("members", members) + "\n"
        + lua_list("literals", strings) + "\n"
        + lua_list("templates", templates)
    )


# The probe's saved variables are Lua, so Lua reads them. Each run comes out as tab-separated
# lines: run, kind, name, answer.
READER = r"""
dofile(arg[1])
local function out(run, kind, name, answer)
    io.write(run, "\t", kind, "\t", name, "\t", (tostring(answer):gsub("[\t\r\n]", " ")), "\n")
end
for run, r in pairs(FamilySurfaceDB or {}) do
    for _, kind in ipairs { "globals", "members", "events", "templates" } do
        for name, answer in pairs(r[kind] or {}) do out(run, kind, name, answer) end
    end
    for _, line in ipairs(r.calls or {}) do
        local name, answer = line:match("^(.-%)) (.*)$")
        out(run, "calls", name or line, answer or "")
    end
    out(run, "interface", "interface", r.interface)
end
"""


def answers(path):
    run = subprocess.run(["lua5.1", "-e", READER.replace("arg[1]", repr(path))],
                         capture_output=True, text=True)
    if run.returncode != 0:
        sys.exit("could not read %s:\n%s" % (path, run.stderr))
    runs = collections.defaultdict(lambda: collections.defaultdict(dict))
    for line in run.stdout.splitlines():
        name, kind, key, answer = line.split("\t", 3)
        runs[name][kind][key] = answer
    if len(runs) != 1:
        sys.exit("%s holds %d runs; --report reads files with exactly one" % (path, len(runs)))
    (label, run_), = runs.items()
    return label, run_


def shape(answer):
    """What a call's answer looks like, without its values: absent, throws, or the types."""
    if answer.startswith("absent") or answer.startswith("throws"):
        return answer.split(" ", 1)[0]
    if not answer.startswith("answers "):
        return answer
    values = answer[len("answers "):]
    if values == "(nothing)":
        return "nothing"
    kinds = []
    for value in values.split(" | "):
        if value.startswith('"'):
            kinds.append("string")
        elif value in ("true", "false"):
            kinds.append("boolean")
        elif value in ("nil", "table", "function", "userdata") or value.startswith("+"):
            kinds.append(value)
        else:
            kinds.append("number")
    return ", ".join(kinds)


def differs(one, other):
    """Whether two answers differ in shape rather than in what the character happens to hold.

    A nil, or nothing at all, is what a client says about a character with no guild or no
    profession, so it matches anything: the first Mists run was a level-one character outside
    a guild, and a plain comparison of types called its empty answers a different API. What
    is left is a different number of values, or two values in one position that are both
    there and of different types."""
    one, other = shape(one), shape(other)
    if "nothing" in (one, other) or one == other:
        return False
    one, other = one.split(", "), other.split(", ")
    if len(one) != len(other):
        return True
    return any(a != b and "nil" not in (a, b) for a, b in zip(one, other))


def report(asked_path, control_path=None):
    uses = collections.defaultdict(set)
    measure(uses)
    label, asked = answers(asked_path)
    control_label, control = answers(control_path) if control_path else (None, None)

    def files(name):
        found = sorted(uses.get(name, ()))
        return ", ".join(found) if found else "(no file found)"

    def section(title, rows):
        print("\n## %s (%d)\n" % (title, len(rows)))
        for row in rows:
            print("- " + row)

    print("# %s, interface %s" % (label, asked["interface"]["interface"]))
    if control:
        print("# against %s, interface %s" % (control_label, control["interface"]["interface"]))

    for kind, word in (("globals", "Globals"), ("members", "Namespace members")):
        rows = []
        for name, answer in sorted(asked[kind].items()):
            if answer != "nil":
                continue
            if control and control[kind].get(name, "nil") == "nil":
                continue
            rows.append("`%s` - %s" % (name, files(name)))
        section(word + " absent" + (", present on the control" if control else ""), rows)

    rows = []
    for name, answer in sorted(asked["events"].items()):
        if answer == "registers":
            continue
        if control and control["events"].get(name) != "registers":
            continue
        rows.append("`%s` - %s" % (name, files(name)))
    section("Literals refused as events" + (", registered on the control" if control else ""),
            rows)

    rows = []
    for name, answer in sorted(asked["templates"].items()):
        if answer != "builds":
            rows.append("`%s` - %s" % (name, answer))
    section("Templates that do not build", rows)

    rows = []
    for name, answer in sorted(asked["calls"].items()):
        if answer.startswith("throws"):
            rows.append("`%s` %s" % (name, answer))
    section("Calls that throw", rows)

    if control:
        rows = []
        for name, answer in sorted(asked["calls"].items()):
            other = control["calls"].get(name)
            if other is None or answer.startswith("absent") or other.startswith("absent"):
                continue
            if differs(answer, other):
                rows.append("`%s`\n  - here: %s\n  - control: %s" % (name, answer, other))
        section("Calls both clients answer, in a different shape", rows)
    else:
        rows = ["`%s` %s" % (name, answer) for name, answer in sorted(asked["calls"].items())
                if not answer.startswith("absent")]
        section("Calls answered", rows)


def main():
    if "--report" in sys.argv[1:]:
        paths = sys.argv[sys.argv.index("--report") + 1:]
        if not 1 <= len(paths) <= 2:
            sys.exit("--report takes the asked client's file and, optionally, a control's")
        report(*paths)
        return
    text = render()
    if "--check" in sys.argv[1:]:
        current = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if current != text:
            sys.exit("%s is out of date: run tools/surface.py" % os.path.relpath(OUT, ROOT))
        print("%s is current" % os.path.relpath(OUT, ROOT))
        return
    with open(OUT, "w", encoding="utf-8") as out:
        out.write(text)
    print("wrote %s" % os.path.relpath(OUT, ROOT))
    print(text.splitlines()[2])


if __name__ == "__main__":
    main()
