# Family — the live check

Everything else Family has can be green while the addon is broken in the game. The harness
stubs the client, so it cannot know whether an API returns what it claims; the contact sheet
settles textures and nothing else. This file is the only gate that runs against a real
client, and it is run by a person because there is no other way to run it.

**A full release does not go out until all three clients have a row** at the bottom of this
file, against the version being cut. An alpha or a beta needs one row rather than three: a
pre-release only reaches the people who go looking for it, and holding one back until every
client has been swept is how the build that would have found the bug stays on this machine.

`tools/release.sh` refuses to tag a version this file has never heard of, so the rule is
enforced where it is broken rather than remembered. What it enforces is that somebody wrote
down what happened — no script can tell whether a client was ever launched. A row reading
*not run: no guildmate* is a true row and passes. An absent row is the release nobody checked.

It exists because four open questions had one cause between them — spec §11.0 and §11.1,
`HANDOFF.md` §4.6 and §4.7 all say, in different words, that nothing has crossed a real
server.

The beta.2 pass closed **three of them**. It did not close §11.1, cross-realm reach, because
this file promised to settle it and then never asked: there was no line about which realms a
link had crossed, so three clients passed and the question stayed exactly where it was. The
line is in the Wide Family section now. A checklist closes a question by asking it, and
believing otherwise is how the gap survived being written down twice.

---

## How to run it

The boxes below are a template to read from, not a form to fill in. Do not tick them, and do
not paste them three times — a tick committed here is a tick nobody can date, and it will
still be there for the next version. Copy them into a scratch file per client if you want
something to tick, and throw it away once the row is written.

The order matters, because the row has to exist before the tag does:

1. `tools/FetchLibs.sh`, then `tools/Deploy.bat`. Wide Family does not exist without the
   libraries and the working tree has none, so a pass run without this tests an addon nobody
   receives.
2. Work down the pass, on each client.
3. Write the rows against the version you are about to cut, and commit them.
4. `tools/release.sh <version>`.

Steps 1 to 3 test the build being tagged rather than the one already published, which is the
only order in which a red result can still stop something.

---

## The pass

Per client: **Era**, **Anniversary**, **Mists**.

### Capabilities — the first thing to look at
- [ ] `/family caps` runs and reports.
- [ ] Every capability it lists as *confirmed* is one the client really has.
- [ ] Nothing it lists as *assumed* is wrong. Assumptions that survive here become §4.7
      answers and go in `DECISIONS.md`.

### One character, end to end
- [ ] Log in and open Family. The summary opens on Overview, listing every character
      recorded on this account — the one being played among them, not singled out.
- [ ] Bags, money and currencies are recorded and the numbers match what the game shows.
- [ ] Professions, talents and gear are recorded. Both specialisations where the client has
      two.
- [ ] **Fold a profession window's categories up and open it again.** Every recipe is still
      recorded, and the window is left folded as you left it. If a profession reads *never
      opened, and listed nothing* after its window has been open, that is the panel telling
      you the window was there and empty — suspect another addon that replaces or filters it
      before suspecting Family. `/family recipes` with the window open shows what the client
      is actually handing back.
- [ ] **On the talent grid, every name matches the talent it sits on**, and the three tree
      headings are the game's own. These come from a generated table, per expansion, and the
      grid is where a wrong one shows: a name one square out means the whole table is
      offset, and it would be offset the same way for every class on that client. Worth a
      look on each of the three, because each has its own table and Mists has its own shape.
- [ ] `/fam` and `/family` both open the window.
- [ ] The **Wide Family** tab is in the strip without anything being switched on, its panel
      explains itself, and its controls do nothing until its box is ticked.
- [ ] **Guild share** is off, and the Guild panel says so rather than looking empty.

### Two characters — the thing Family is for
- [ ] Log to a second character on the same realm. The first appears, with its own numbers.
- [ ] Its bags are still right, drawn from storage rather than from the live client.
- [ ] A tooltip on an item held by the first character names them while you are on the
      second.
- [ ] On each of the seven column sets in turn: rows sit under their own realm's heading,
      and the two banner buttons at the top right remove that side's rows, any column only
      they had, and their share of the totals.

### Mail — the one prediction Family makes
- [ ] Post an item and some money from A to B. It appears against B immediately, marked as
      in the post.
- [ ] Log to B and open the mailbox. What is really there replaces the prediction.
- [ ] A send the server refuses records nothing.

### Guild share — carries data off this machine
- [ ] With a second account or a guildmate running Family: their characters appear.
- [ ] Someone in the guild not running Family is named as such rather than left blank.
- [ ] Switching it off silences it in both directions — announcing does nothing, and asking
      for an update says so rather than appearing to work.
- [ ] Nothing but class, level, gear and talent shape crosses. Bags, mail and money do not —
      **except a profession you have ticked**, which is the section below.

#### Shared professions, with a guildmate
- [ ] Tick **one** profession on one of your characters. On their client, that character
      shows that profession with its skill level beside it — and only that one, not the
      others the same character has.
- [ ] What crossed is a **rank**. Nothing on their side says your character knows any
      particular pattern, because no recipe list has been sent yet.
- [ ] **Untick it, and then touch nothing on either client.** Within a minute it is gone from
      their side. Neither of you presses *Update now*: a withdrawal that waits for a button is
      not a withdrawal, and this is the only place that can be tested at all.
- [ ] Tick four boxes one after another, then `/family guild test` on your side. It counts
      **one** message sent for the lot, not four. Ticking a grid is one decision to everybody
      else in the guild.
- [ ] A guildmate on an **older Family** still exchanges gear and talents with you, and simply
      shows no professions. Note their version in the row if you have one to test against.
- [ ] **Hover something one of their shared professions can make.** A *Guild crafters* block
      appears under your own family's, naming the player and the character of theirs that can
      make it. It works on the crafted item, not only on the pattern.
- [ ] **On Mists only:** open a profession and run `/family recipes`. Each row should print an
      item id as well as a spell id. That window answers with recipe ids and has to be asked
      separately what each one makes; the call is made but has never been seen answering on a
      live client, so this line is a measurement rather than a tick. Write the answer in the
      row — and if the item ids are absent, *Smelt Copper* will not be found by hovering a
      Copper Bar.
- [ ] **Hover something one of your own characters can make.** A *Can make it* block names
      them with their skill, whether or not anybody in the guild can make it too — and the
      guild's are on the same block, marked *(guild)*.
- [ ] **Hover an enchant** — one that makes no object at all — in a trade skill window or from
      a link. The guild's answer appears on the recipe's own tooltip, which for an enchant is
      the only tooltip there is.
- [ ] **Click a recipe row that ends in a count** (`+3`). It unfolds into every crafter and
      folds away again on a second click.
- [ ] Search that recipe's name in **Professions / Whole family**. The row carries a *guild*
      group beside your own crafters, or is a row of its own if nobody at home knows it.
- [ ] **On a client set to another language**, the same search finds the same recipe. Only
      identifiers crossed, so the name comes from your own client — this is the one line that
      proves it end to end, and the languages used go in the row.
- [ ] Untick that profession on their side. Within a minute, and with neither of you pressing
      *Update now*, the recipe stops being attributed to them here.

### Shared professions — the grid, which needs nobody but you

Everything here is testable alone, and it is a section of its own for that reason: the lines
above need a guildmate, and a pass that honestly says *not run: no guildmate* would otherwise
take these with it.

- [ ] The Guild tab shows **What you share with <guild>** above the roster, folded, with the
      heading saying how much is offered. Clicking the heading opens it: a row per character
      of yours in the guild, and a tick box per profession each of them has. It stays as you
      left it across a reload.
- [ ] **Every box actually ticks when clicked**, and no row lights up under the cursor while
      you are aiming at one. A row that highlights under a box is a row that is swallowing the
      click, and the box will be a picture (L-022).
- [ ] `/family guild test` lists **characters of ours with no guild recorded**. Every name on
      that list should be a character genuinely in no guild. If one of them *is* in a guild,
      log in on it once and run the command again — it should drop off. If it does not, that
      is a finding and the character and the client go in the row (L-023).
- [ ] The **running Family** count on the line above is a count of *people*. If several of
      your own characters are in the guild, they count as one between them — you.
- [ ] With guild share **off**, every box is greyed and so are the words beside it, and the
      panel says the switch is in Options. Nothing can be ticked.
- [ ] Switch it on. The boxes come live and **every one of them starts unticked.** A grid
      nobody has touched is the state Family arrives in, so a box already ticked on a database
      where nobody has ever ticked one is a fault rather than a convenience.
- [ ] Tick one and the line under the grid counts it. Untick it and the line says nothing is
      ticked.
- [ ] A character of yours in the guild with no professions recorded says so, and says to open
      a profession window once — rather than showing an empty row.
- [ ] On a character not played for a while, the grid offers its professions rather than
      claiming it has none. Those were recorded under their names before Family kept track of
      professions by identity, and they are resolved on the way in.
- [ ] The *Not offered* line, if it appears, **fits on one line**. It does not wrap and it is
      capped at six names, so a longer list ends with "and N more" rather than running off the
      right-hand edge. The harness cannot measure text, so this one is only checkable here.
- [ ] **Whether the *left out* line appears at all, and what it names.** It counts
      professions this client gave no identifier for, and on a healthy client it should not
      appear. If it does, write the number and the client into the row: it means the skill
      line table is missing something that client has, which is a finding and not a passing
      line.
- [ ] On a non-English client, every profession in the grid is named in that client's own
      language.
- [ ] Log to an alt in a **different guild**, and back. The first guild's records and its
      ticked grid are **still there.** What Family forgets is decided from your own
      characters' guilds, and having a second guild must never cost you the first one's.

### Wide Family — only once the above is clean
- [ ] About says *compressed storage*, not *uncompressed*. A checkout has no `Libs` and
      `Deploy.bat` copies the checkout, so without `tools/FetchLibs.sh` there is no Wide
      Family on this build to test and every line below it would pass by being absent.
- [ ] A link request reaches the other family and can be accepted.
- [ ] **Ask two characters of the same family, then accept on one.** The request to the other
      clears itself on your panel rather than waiting for ever — a link is between families.
- [ ] Exactly what was granted crosses, and nothing else.
- [ ] An exchange interrupted by a logout is abandoned rather than hanging.
- [ ] **Reach.** Note which realm the other family is on and whether it worked: same realm,
      a connected one, an unconnected one. This is spec §11.1 and it is the one open question
      a pass can close — but only if the answer is written down, so put it in the row.

### Nothing is on fire
- [ ] No Lua errors with the error display on, through the whole pass.
- [ ] Reload. Everything above is still true.

---

## Runs

| Version | Client | Date | By | Result |
|---|---|---|---|---|
| v1.0.0-beta.1 | Anniversary | 27/8/26 | Alberto | Pass except Wide Family last line unchecked |
| v1.0.0-beta.1 | Era | 27/8/26 | Alberto | Pass except Wide Family last line unchecked |
| v1.0.0-beta.1 | Mists | 27/8/26 | Alberto | Pass except Wide Family last line unchecked |
| v1.0.0-beta.2 | Anniversary | 27/8/26 | Alberto | Pass  |
| v1.0.0-beta.2 | Era | 27/8/26 | Alberto | Pass |
| v1.0.0-beta.2 | Mists | 27/8/26 | Alberto | Pass |
| v1.0.0-beta.3 | Anniversary | 27/8/26 | Alberto | Pass  |
| v1.0.0-beta.3 | Era | 27/8/26 | Alberto | Pass |
| v1.0.0-beta.3 | Mists | 27/8/26 | Alberto | Pass |
| v1.0.0 | Anniversary | 29/8/26 | Alberto | Pass  |
| v1.0.0 | Era | 29/8/26 | Alberto | Pass |
| v1.0.0 | Mists | 29/8/26 | Alberto | Pass |
| v1.1.0 | Anniversary | 29/8/26 | Alberto | Pass  |
| v1.1.0 | Era | 29/8/26 | Alberto | Pass |
| v1.1.0 | Mists | 29/8/26 | Alberto | Pass |

*Client* is `Era`, `Anniversary` or `Mists` — the three the `.toc` names. *Result* is `pass`, or what was not run and
why — the sections needing a guildmate or a second family are the ones that will honestly say
so. The version cell may carry the `v` or leave it off; `release.sh` reads either.
