#!/usr/bin/env bash
# Family - an alt manager for World of Warcraft Classic
# Copyright (C) 2026 Alberto Pittaluga
#
# This program is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# See the LICENSE file at the root of this repository.
#
# Fetching the libraries a released copy of Family has and a git clone does not.
#
#     tools/FetchLibs.sh
#
# .pkgmeta lists LibStub, LibSerialize and LibDeflate as externals, so CurseForge builds them
# into the zip and this repository holds only what we wrote (HANDOFF §2). That is the right
# arrangement for shipping and the wrong one for testing: Deploy.bat copies the working tree
# into the game, the working tree has no Libs folder, and Wide Family cannot send a byte
# without them. What a player gets and what the developer runs are then not the same addon,
# and the difference is exactly the feature under test.
#
# This closes that gap by fetching the same three libraries from the same three upstreams
# .pkgmeta names, into the layout Family.toc already lists. They stay untracked - .gitignore
# has the folder - so nothing about what this repository contains changes.
#
# Run it once, and again whenever you want the libraries brought up to date.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

libs="addons/Family/Libs"

fail() { printf '%s\n' "$*" >&2; exit 1; }

[[ -f "addons/Family/Family.toc" ]] || fail "this is not Family's checkout - no addons/Family/Family.toc"
command -v git >/dev/null || fail "git is needed and is not on the path"
command -v curl >/dev/null || fail "curl is needed and is not on the path"

# A file that arrived as a 404 page, a login form or an empty body is worse than one that did
# not arrive: it is Lua the game will try to run. Anything implausibly small for a library is
# treated as a failure rather than saved.
check() {
    local path="$1" least="$2"
    [[ -f "$path" ]] || fail "$path was not written - fetch failed"
    local size
    size="$(wc -c < "$path")"
    [[ "$size" -ge "$least" ]] \
        || fail "$path is only $size bytes, which is not a library - fetch failed"
    head -c 400 "$path" | grep -qi "<!doctype\|<html" \
        && fail "$path is a web page rather than Lua - fetch failed"
    printf '     %-28s %8s bytes\n' "$(basename "$path")" "$size"
    return 0
}

# Cloned to a scratch folder and copied out of it: these repositories carry tests, docs and
# rockspecs that have no business in an addon folder, and the .toc names the single file it
# wants from each.
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

echo "==> clearing $libs"
rm -rf "$libs"
mkdir -p "$libs/LibStub" "$libs/LibSerialize" "$libs/LibDeflate"

# LibStub is not optional despite being three lines of nothing. Neither of the other two
# publishes itself any other way: without LibStub each builds a plain table and returns it,
# and the game discards what a file loaded from a .toc returns. No LibStub, no way to reach
# them, whether or not they loaded.
echo "==> LibStub"
curl -sSL --max-time 60 -o "$libs/LibStub/LibStub.lua" \
    "https://repos.wowace.com/wow/libstub/trunk/LibStub.lua"
check "$libs/LibStub/LibStub.lua" 500

echo "==> LibSerialize"
git clone -q --depth 1 https://github.com/rossnichols/LibSerialize.git "$scratch/LibSerialize"
cp "$scratch/LibSerialize/LibSerialize.lua" "$libs/LibSerialize/"
# Their licence travels with their code. Ours is GPL and theirs is not, and a folder of
# somebody else's work with no licence in it is the one thing this project must not ship.
cp "$scratch/LibSerialize/LICENSE" "$libs/LibSerialize/" 2>/dev/null || true
check "$libs/LibSerialize/LibSerialize.lua" 20000

echo "==> LibDeflate"
git clone -q --depth 1 https://github.com/SafeteeWoW/LibDeflate.git "$scratch/LibDeflate"
cp "$scratch/LibDeflate/LibDeflate.lua" "$libs/LibDeflate/"
cp "$scratch/LibDeflate/LICENSE.txt" "$libs/LibDeflate/" 2>/dev/null || true
check "$libs/LibDeflate/LibDeflate.lua" 50000

cat <<EOF

Fetched into $libs, which is untracked - git status will not show it and no release
is affected. CurseForge builds its own copies from the same upstreams (.pkgmeta).

Deploy.bat will now carry them into the game, so the client you test on has the
compression and the Wide Family a released copy has. To check it took, in game:

    /family caps

and the About panel's header line should read "compressed storage" rather than
"uncompressed storage".
EOF
