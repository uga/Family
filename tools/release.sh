#!/usr/bin/env bash
# Family - an alt manager for World of Warcraft Classic
# Copyright (C) 2026 Alberto Pittaluga
#
# This program is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later version.
# See the LICENSE file at the root of this repository.
#
# Drawing a line and calling it a release.
#
#     tools/release.sh 0.2.0
#
# Not every commit is a release and this is what makes the difference visible: it bumps both
# .toc files, turns the Unreleased section of the changelog into a dated section for this
# version, commits that, and pushes a tag. The tag is what the GitHub workflow watches, so
# pushing it is the act of publishing and nothing before it is.
#
# It refuses rather than guesses: a dirty tree, a version that already exists, a changelog
# with nothing under Unreleased, a version with no run recorded in docs/SMOKE.md, or a failing
# check all stop it where it stands. A release that went out because a script pressed on is
# worse than one that did not go out.

set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$here"

version="${1:-}"

fail() { printf '%s\n' "$*" >&2; exit 1; }

[[ -n "$version" ]] || fail "usage: tools/release.sh <version>, e.g. tools/release.sh 0.2.0"

# Three numbers, optionally followed by an alpha or beta count. CurseForge sorts releases by
# them and a version that does not parse sorts somewhere nobody expects.
#
# The suffix is not decoration. The packager reads the tag and marks the CurseForge file as
# alpha when the tag contains the word "alpha", beta when it contains "beta", and a full
# release otherwise - so the difference between a version people are offered by default and
# one only opted-in testers see is these few characters, and nothing else.
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta)\.[0-9]+)?$ ]] \
    || fail "version must look like 1.2.3, 1.2.3-alpha.1 or 1.2.3-beta.2, got '$version'"

case "$version" in
    *alpha*) channel="an ALPHA - CurseForge will not offer it as the default download" ;;
    *beta*)  channel="a BETA - CurseForge will not offer it as the default download" ;;
    *)       channel="a full RELEASE - this is what CurseForge offers everybody by default" ;;
esac

git diff --quiet && git diff --cached --quiet \
    || fail "the tree has uncommitted changes - commit or stash them first"

git rev-parse --verify --quiet "refs/tags/v$version" >/dev/null \
    && fail "v$version already exists"

# What goes in the release notes: everything between the Unreleased heading and the next
# version heading. Empty means nobody wrote down what changed, and shipping a release whose
# notes say nothing is worse than stopping to write them.
#
# This is also what CurseForge shows, and it did not used to be. `manual-changelog` in
# .pkgmeta names a file and the packager sends that file **whole** - pointed at CHANGELOG.md
# it published every version since 1.0.0 on every release, 58 kB of history under an empty
# Unreleased heading, while two comments in this repository said it published the section.
# Nobody had opened a published release to look. So the section is written to its own file
# below and .pkgmeta points at that.
notes="$(awk '/^## Unreleased/{found=1; next} found && /^## /{exit} found' CHANGELOG.md)"
[[ -n "$(printf '%s' "$notes" | tr -d '[:space:]')" ]] \
    || fail "CHANGELOG.md has nothing under Unreleased - write what changed first"

# The live checklist is the only gate that runs against a real client, and a person runs it.
# Nothing here can tell whether that happened; what it can tell is whether anybody wrote the
# result down, which is the whole difference between a release that was checked and one that
# was assumed. docs/SMOKE.md sets the bar: a full release needs all three clients recorded
# against this version, a pre-release needs one row, and a row that honestly says what was not
# run counts. v1.0.0-beta.1 went out with that rule written down and nothing enforcing it.
smoke="docs/SMOKE.md"
[[ -f "$smoke" ]] || fail "$smoke is missing - it is the live check and this is the gate that reads it"

# Rows for this version, reduced to their client cell. The version cell may carry the v or
# leave it off, and the table's own header and rule lines match neither.
clients="$(awk -F'|' -v want="$version" '
    /^\|/ {
        cell = $2
        gsub(/^[ \t]+|[ \t]+$/, "", cell)
        sub(/^v/, "", cell)
        if (cell == want) print tolower($3)
    }
' "$smoke")"

[[ -n "$clients" ]] || fail "$smoke records no run for $version - run the live check and write the rows before cutting it"

# A pre-release reaches only the people who go looking for it, so one row is the bar. A full
# release is what CurseForge offers everybody by default, and that needs all three.
case "$version" in
    *alpha*|*beta*) ;;
    *)
        for client in Era:era Anniversary:anni Mists:mists; do
            name="${client%%:*}"
            match="${client##*:}"
            grep -q "$match" <<<"$clients" \
                || fail "$smoke records no $name run for $version - a full release needs all three clients"
        done
        ;;
esac

echo "==> checks"
lua tests/Harness.lua >/dev/null || fail "checks failed - nothing is released on a red run"

echo "==> version $version in both .toc files"
for toc in addons/Family/Family.toc addons/Family_UI/Family_UI.toc; do
    grep -q '^## Version:' "$toc" || fail "$toc has no ## Version line"
    sed -i "s/^## Version:.*/## Version: $version/" "$toc"
done

echo "==> changelog"
today="$(date +%Y-%m-%d)"
# Unreleased becomes this version and dated, and a fresh empty Unreleased goes above it so
# the next change has somewhere to be written the moment it lands.
awk -v version="$version" -v today="$today" '
    /^## Unreleased/ && !done {
        print "## Unreleased"
        print ""
        print "## " version " — " today
        done = 1
        next
    }
    { print }
' CHANGELOG.md > CHANGELOG.md.new && mv CHANGELOG.md.new CHANGELOG.md

# The notes as CurseForge will show them: this version's section, and nothing else. Written
# into the release commit so that the tag carries it and the packager finds it in the checkout.
printf '## %s \u2014 %s\n%s\n' "$version" "$today" "$notes" > RELEASE-NOTES.md

git add addons/Family/Family.toc addons/Family_UI/Family_UI.toc CHANGELOG.md RELEASE-NOTES.md
git commit -q -m "Release $version"
git tag -a "v$version" -m "Family $version

$notes"

cat <<EOF

Committed and tagged v$version, which will be published as $channel.

Nothing has been published yet.

Before you push: does docs/MANUAL.md still describe what these notes say Family does? Nothing
checks that and nothing can - a document cannot be tested for describing last month's
behaviour. It is the last thing that is still cheap to fix.

    git push && git push origin v$version

That push is what starts the workflow, and the workflow is what uploads. Until then this
is a local decision you can undo with:

    git tag -d v$version && git reset --hard HEAD~1
EOF
