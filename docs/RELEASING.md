# Family — releasing

How a version of Family reaches players, and the four things a machine cannot do for you.

The rule this is built around: **not every commit is a release.** Work lands on `main` as it
is finished; a release is a separate decision, taken by a person, and the act that takes it is
pushing a tag. Nothing before that publishes anything.

---

## Once, by hand

These four need an account and a browser, so they are yours. Everything after them is one
command.

**1. Create the CurseForge project.**
Sign in at [legacy.curseforge.com](https://legacy.curseforge.com/wow/addons) and create a new
project. Name it `Family`, choose the *Addons* category, and set the licence to
**GPL-3.0-or-later** to match [`LICENSE`](../LICENSE). Set the supported game versions to
Classic Era, Burning Crusade Classic and Mists of Pandaria Classic — the packager also reads
`## Interface` from the `.toc`, but the project page has its own list.

The *Description* box is the one part of the page CurseForge will reject a project over: it
wants the features, what each does to a player's experience, and a reason to download, in
detail. The text to paste is [`CURSEFORGE.md`](CURSEFORGE.md), kept in the repository so it is
reviewed like everything else and so the next version can start from what the last one said.

**2. Get an API token.**
On CurseForge, under your account: *My API Tokens* → generate one. It is shown once.

**3. Put the token where the workflow can reach it.**
In this repository on GitHub: *Settings* → *Secrets and variables* → *Actions* → *New
repository secret*, named exactly:

| Secret | What it is | Needed? |
|---|---|---|
| `CF_API_KEY` | the CurseForge token from step 2 | yes |
| `WOWI_API_TOKEN` | WoWInterface, if you ever want it there too | no |
| `WAGO_API_TOKEN` | Wago Addons, likewise | no |

A secret that is absent means that destination is skipped rather than failing the run, so
CurseForge alone is a complete setup.

**4. Tell the packager which project to upload to.**
Add the project id to both `.toc` files — CurseForge shows it on the project page, top right,
as *Project ID*:

```
## X-Curse-Project-ID: 1646217
```

Until this is set the workflow will build the zip and have nowhere to send it, which is a
clear failure rather than a silent one.

---

## Every time

**First, the live check.** [`SMOKE.md`](SMOKE.md) is the only gate that runs against a real
client, and a person runs it because there is no other way to. Its rows are what the command
below reads: a full release needs Era, Burning Crusade and Mists recorded against the version
being cut, and a pre-release needs one row. Write them and commit them first — the command
refuses to tag a version that file has never heard of.

That order is deliberate. The pass is run against the build about to be tagged, deployed with
`tools/FetchLibs.sh` and `Deploy.bat`, rather than against the version already published; it
is the only order in which a red result can still stop something.

**Then the effort log.** `tools/effort.py --write` regenerates
[`EFFORT.md`](EFFORT.md) from Claude Code's own transcripts. Before running it, add anything to
[`docs/effort/declared.csv`](effort/declared.csv) that happened away from the tool since the
last release — testing in the game above all, which is most of the real work on an addon and
appears in no transcript anywhere. Approximate is fine; absent is not.

**Then the manual.** Read the **Unreleased** section of the changelog against
[`MANUAL.md`](MANUAL.md) and bring the manual into line with anything a user would meet: a new
column, a panel that behaves differently, a question §15 should now answer. Nothing enforces
this — a document cannot be checked for describing last month's behaviour — so it is a step
here, done before the notes are consumed by the command below and are still in front of you.

The manual is English only, deliberately. The one inside the addon, on the **About** tab, is
translated into all five languages and is the one a player who never leaves the game will read.

```bash
tools/release.sh 0.2.0
```

It bumps the version in both `.toc` files, turns the **Unreleased** section of
[`CHANGELOG.md`](../CHANGELOG.md) into a dated section for this version, commits that, and
makes an annotated tag carrying the notes. Then it prints the push command and stops, because
pushing is the publishing and it should be a thing you do rather than a thing that happens.

```bash
git push && git push origin v0.2.0
```

The tag push starts [`.github/workflows/release.yml`](../.github/workflows/release.yml),
which runs the checks, builds the zip and uploads it.

It refuses to start on a dirty tree, on a version that already exists, on a changelog with
nothing under **Unreleased**, on a version with no run recorded in [`SMOKE.md`](SMOKE.md), or
on a failing check. A release that went out because a script
pressed on regardless is worse than one that did not go out.

### Undoing one, before it is pushed

```bash
git tag -d v0.2.0 && git reset --hard HEAD~1
```

After it is pushed, it is published. Cut the next version rather than trying to withdraw one:
a version number that existed and then meant something else is worse for everybody than a
version number that was superseded quickly.

### When the run goes red after the upload succeeded

A red run does not mean the release did not happen. The workflow talks to two services from
one step, they do not share a transaction, and the CurseForge half is the half that cannot be
taken back — so the first job is not to fix anything, it is to find out which half is done.

**Read the run before touching it.** Open the failed run under *Actions* → *Release* and
expand *Package and upload*. The packager uploads to CurseForge first and creates the GitHub
release second, so a log that reports the upload succeeding and then fails is the expensive
shape: a version that is public on CurseForge with no GitHub release pointing at it. Confirm
it on the project's *Files* page rather than on the log alone — that page is what players see.

**Do not re-run the workflow, and do not re-push the tag.** Re-running repeats the upload, and
CurseForge accepts it: the project ends up carrying two files for one version number, which is
a worse problem than the one being fixed. That is the whole reason this recovery is by hand.

**Create the missing release by hand.** The tag already carries the notes `release.sh` built
from the changelog, so nothing has to be written twice:

```bash
gh release create v0.2.0 --verify-tag --notes-from-tag
```

`--verify-tag` refuses if the tag never reached the remote, and `--notes-from-tag` takes the
title from the tag's first line and the body from the rest — which is what the workflow would
have done. `v1.0.0-beta.1` was recovered exactly this way.

**Then fix the cause, and leave a check behind.** The version is already out; what is left is
making sure the next release does not need this page. L-009 in [`LESSONS.md`](LESSONS.md) is
the first instance and the pattern for the rest: the harness now reads `release.yml` and fails
unless the job grants `contents: write`, and because `release.sh` runs the harness before it
tags, that check stands between the mistake and the tag rather than after it.

If the run went red *before* the upload — at the checks, or in the packager itself — then
nothing is public and there is nothing to withdraw. The tag is spent all the same: the rule
above holds, and the fix goes out as the next version rather than as this one a second time.

---

## What is in the zip

Two folders, `Family` and `Family_UI`, and nothing else. `.pkgmeta` says so and says why:
neither addon is useful without the other, so they travel together and a player installs one
thing. `tools/`, `tests/` and `docs/` are for people reading the source and are left out.

**Libraries are fetched at package time, not committed.** `.pkgmeta` lists `LibStub`,
`LibSerialize` and `LibDeflate` as externals, so they arrive at their own upstream version and
their licences stay theirs — see [`HANDOFF.md`](HANDOFF.md) §2. This repository holds only what
we wrote.

They are optional everywhere in Family except Wide Family, which cannot exist without them:
the addon channel carries a string and nothing else. A copy built straight from a `git clone`
therefore runs with no compression and no Wide Family, and says so in the About panel. A copy
installed from CurseForge has both.

### Testing a build that has them

`Deploy.bat` copies the working tree, and the working tree has no `Libs` folder — so the
client you develop against is not the addon anybody receives, and the difference is exactly
Wide Family. Close that gap before testing it:

```bash
tools/FetchLibs.sh
```

It fetches the same three libraries from the same three upstreams `.pkgmeta` names, into the
layout `Family.toc` already lists, and refuses anything that came back too small or came back
as a web page. They land in `addons/Family/Libs/`, which `.gitignore` covers, so nothing about
what this repository holds changes and no release is affected.

To confirm it took, the About panel's header line should read *compressed storage* rather than
*uncompressed storage*.

---

## Version numbers

`major.minor.patch`, optionally `-alpha.N` or `-beta.N`, and CurseForge sorts on them, so they
have to parse.

What the three of them mean, so that a player reading a version number learns something from
it rather than only that it changed:

| Part | Goes up when |
|---|---|
| **major** | a revamp, or a function Family did not have before |
| **minor** | a fix, including the ones a Blizzard patch makes necessary |
| **patch** | nothing but a `## Interface` bump, to stay current with a patch that broke nothing |

The suffix is separate from all three: it is the channel, not the size of the change.

**The suffix decides who gets it.** The packager reads the tag: one containing the word
*alpha* is uploaded as an alpha file, *beta* as a beta, and anything else as a full release —
verified against the packager's own source, not assumed. CurseForge offers only the newest
*release* as the default download; alphas and betas are there for people who go looking. So
`v1.0.0-alpha.1` puts a build in front of testers without putting it in front of everybody,
and that is the whole mechanism.

`tools/release.sh` prints which of the three a version will be before you push it.

`1.0` is a promise about the saved variables, and it is made: from here the format is
**migrated, never reset**. `Database.lua` carries the schema number and the migrations that
run against it, and a change to the shape of what Family stores arrives as another migration
rather than as a version that quietly starts somebody's records again from empty.

That is why the first `1.0` goes out as a beta. CurseForge offers only the newest full
release as the default download, so `1.0.0-beta.1` reaches the people who go looking for it
and nobody else — which is the right size of audience for a promise whose first test is other
people's data.
