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
server. A checklist that has been run closes all four.

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
- [ ] `/fam` and `/family` both open the window.

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
- [ ] Nothing but class, level, gear and talent shape crosses. Bags, mail and money do not.

### Wide Family — only once the above is clean
- [ ] About says *compressed storage*, not *uncompressed*. A checkout has no `Libs` and
      `Deploy.bat` copies the checkout, so without `tools/FetchLibs.sh` there is no Wide
      Family on this build to test and every line below it would pass by being absent.
- [ ] A link request reaches the other family and can be accepted.
- [ ] Exactly what was granted crosses, and nothing else.
- [ ] An exchange interrupted by a logout is abandoned rather than hanging.

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

*Client* is `Era`, `Anniversary` or `Mists` — the three the `.toc` names. *Result* is `pass`, or what was not run and
why — the sections needing a guildmate or a second family are the ones that will honestly say
so. The version cell may carry the `v` or leave it off; `release.sh` reads either.
