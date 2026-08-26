#!/usr/bin/env python3
"""Builds the skill thresholds that colour a recipe, from the client's own tables.

One source, and it is the client: the SkillLineAbility table pulled from wago.tools for the
exact build the game is on. It carries TrivialSkillLineRankLow, the skill at which a recipe
turns yellow, and TrivialSkillLineRankHigh, where it turns grey.

What the client does not carry is the orange point. A recipe is orange from the moment it is
learned, and what you are allowed to learn is decided by the trainer - server data, which is
not ours to have. Two things stand in for it, in order:

  * the skill the recipe item itself demands, from ItemSparse.RequiredSkillRank by way of
    ItemEffect. A recipe that drops carries its requirement on the item that teaches it, so
    this covers everything except the trainer-taught ones.
  * MinSkillLineRank from the client's own row, where that says anything above 1.

Where neither speaks, orange is stood on the yellow point. That is a guess, it is the
smallest one available - it understates the orange band rather than inventing one - and it is
counted and reported rather than hidden.

Green is not stored by anyone. The client computes it as the midpoint between yellow and
grey, and so does this.

A row is dropped if the four numbers do not come out in order, and the dropped spell ids are
printed so the count can be looked at rather than assumed.

Usage:  python3 tools/GenerateCraftLevels.py [--cache DIR] [--out FILE]

Downloads are kept in the cache directory so the file can be rebuilt without the network.
The output is generated data and is never committed - see docs/HANDOFF.md §3.
"""

import argparse
import csv
import io
import os
import urllib.request

# Pinned to the builds this fork targets. Bump them when the clients move; the numbers are
# stable across patches, but the recipe list is not.
BUILDS = {
	"classic": ("wow_classic_era", "1.15.9.69109"),
	"tbc": ("wow_anniversary", "2.5.6.69110"),
	"mop-classic": ("wow_classic", "5.5.4.69078"),
}

# Oldest first, each holding only what it changes from the ones below it, with the interface
# number that admits it.
LAYERS = [("classic", None), ("tbc", 20000), ("mop-classic", 50000)]

UA = {"User-Agent": "Family-CraftLevels/1.0"}


def fetch(url, path):
	if os.path.exists(path) and os.path.getsize(path) > 0:
		return open(path, encoding="utf8", errors="ignore").read()

	body = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=90).read()
	open(path, "wb").write(body)
	return body.decode("utf8", errors="ignore")


def read_client(cache, build):
	"""spellID -> (minRank, yellow, grey), from the client's own table."""
	text = fetch(f"https://wago.tools/db2/SkillLineAbility/csv?build={build}",
		os.path.join(cache, f"SkillLineAbility_{build}.csv"))

	out = {}
	for row in csv.DictReader(io.StringIO(text)):
		yellow = int(row["TrivialSkillLineRankLow"])
		grey = int(row["TrivialSkillLineRankHigh"])

		# a row without a yellow point is an ability, not a recipe
		if yellow > 0:
			out.setdefault(int(row["Spell"]), (int(row["MinSkillLineRank"]), yellow, grey))

	return out


def read_recipe_items(cache, build):
	"""spellID -> the skill a recipe item asks for.

	A recipe taught by a trainer carries its requirement in the trainer's list, which is server
	data and nowhere in the client. A recipe that drops carries it on the item that teaches it,
	and that is here. This is where the orange point comes from for everything that is not
	trainer-taught.
	"""
	effects = fetch(f"https://wago.tools/db2/ItemEffect/csv?build={build}",
		os.path.join(cache, f"ItemEffect_{build}.csv"))
	items = fetch(f"https://wago.tools/db2/ItemSparse/csv?build={build}",
		os.path.join(cache, f"ItemSparse_{build}.csv"))

	required = {}
	for row in csv.DictReader(io.StringIO(items)):
		rank = int(row["RequiredSkillRank"] or 0)
		if rank:
			required[int(row["ID"])] = rank

	out = {}
	for row in csv.DictReader(io.StringIO(effects)):
		spell = int(row["SpellID"])
		rank = required.get(int(row["ParentItemID"]))

		if spell and rank:
			out[spell] = min(out.get(spell, rank), rank)

	return out


def build(cache, game):
	client = read_client(cache, BUILDS[game][1])
	taught = read_recipe_items(cache, BUILDS[game][1])

	levels, dropped, guessed = {}, [], 0
	for spell, (c_min, yellow, grey) in client.items():
		orange = taught.get(spell) or (c_min if c_min > 1 else 0)
		green = (yellow + grey) // 2

		# nobody publishes where the trainer-taught ones start. Standing them on the yellow
		# point is the smallest lie available: it understates the orange band rather than
		# inventing one.
		if not orange:
			orange = yellow
			guessed += 1

		# a recipe can be learned at a point where it is already yellow - Coarse Sharpening
		# Stone is one - so the two meeting is not an error.
		orange = min(orange, yellow)

		# the learned-at level was trainer data and is gone with it. The orange point is the
		# honest stand-in: it is the skill at which the recipe first does anything.
		learned = orange

		if not (0 < orange <= yellow <= green <= grey <= 1023 and learned <= 1023):
			dropped.append(spell)
			continue

		levels[spell] = (learned << 40) + (orange << 30) + (yellow << 20) + (green << 10) + grey

	return levels, dropped, guessed


def emit(path, layers):
	"""layers: [(game, interface threshold or None, levels)], oldest first."""

	def block(levels, indent):
		return "\n".join(f"{indent}[{spell}] = {levels[spell]}," for spell in sorted(levels))

	base = layers[0][2]
	visible = dict(base)
	blocks = []

	for game, threshold, levels in layers[1:]:
		delta = {k: v for k, v in levels.items() if visible.get(k) != v}
		blocks.append((game, threshold, delta))
		visible.update(levels)

	layered = "\n".join("""
if select(4, GetBuildInfo()) >= %d then
\tlocal newer = {
%s
\t}

\tfor spellID, levels in pairs(newer) do
\t\tFamily.CraftLevels[spellID] = levels
\tend
end""" % (threshold, block(delta, chr(9) * 2)) for _, threshold, delta in blocks)

	builds = ", ".join(BUILDS[game][1] for game, _ in LAYERS)

	body = f"""-- Generated by tools/GenerateCraftLevels.py - do not edit by hand.
--
-- Source: the client's own SkillLineAbility, ItemEffect and ItemSparse tables for {builds},
-- taken from wago.tools. See the tool for how the orange point is arrived at.
--
-- Each entry packs, ten bits at a time from the bottom: grey, green, yellow, orange, and the
-- level the recipe is learned at. The base is Classic Era; each later game is a block of its own
-- holding only what it changes, read in order, and only on a client that has reached it.

local _, Family = ...

Family.CraftLevels = {{
{block(base, chr(9))}
}}
{layered}
"""
	open(path, "w", encoding="utf8", newline="\n").write(body)
	return [(g, len(d)) for g, _, d in blocks]


def main():
	ap = argparse.ArgumentParser()
	ap.add_argument("--cache", default=os.path.join(os.path.dirname(__file__), ".craftlevels-cache"))
	ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "addons",
		"Family", "Data", "CraftLevels.lua"))
	args = ap.parse_args()

	os.makedirs(args.cache, exist_ok=True)
	os.makedirs(os.path.dirname(os.path.abspath(args.out)), exist_ok=True)

	built, dropped = [], []
	for game, threshold in LAYERS:
		levels, gone, guessed = build(args.cache, game)
		built.append((game, threshold, levels))
		dropped += gone
		print(f"\n{game:12}: {len(levels)} recipes, {guessed} with no published orange point")

	for game, count in emit(os.path.abspath(args.out), built):
		print(f"layer {game:12}: {count} to add or correct")

	for spell in dropped:
		print(f"  dropped: spell {spell}, thresholds not in order")


if __name__ == "__main__":
	main()
