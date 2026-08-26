# Family — the live check

Everything else Family has can be green while the addon is broken in the game. The harness
stubs the client, so it cannot know whether an API returns what it claims; the contact sheet
settles textures and nothing else. This file is the only gate that runs against a real
client, and it is run by a person because there is no other way to run it.

**Run it on each of the three clients before pushing a `v*` tag.** Record the result at the
bottom, against the version it was run for. A release whose row is missing is a release that
was not checked, and `docs/RELEASING.md` treats that as a stop.

It exists because four open questions had one cause between them — spec §11.0 and §11.1,
`HANDOFF.md` §4.6 and §4.7 all say, in different words, that nothing has crossed a real
server. A checklist that has been run closes all four.

---

## The pass

Per client: **Era**, **Burning Crusade**, **Mists**.

### Capabilities — the first thing to look at
- [ ] `/family caps` runs and reports.
- [ ] Every capability it lists as *confirmed* is one the client really has.
- [ ] Nothing it lists as *assumed* is wrong. Assumptions that survive here become §4.7
      answers and go in `DECISIONS.md`.

### One character, end to end
- [ ] Log in. The summary opens on the character being played.
- [ ] Bags, money and currencies are recorded and the numbers match what the game shows.
- [ ] Professions, talents and gear are recorded. Both specialisations where the client has
      two.
- [ ] `/fam` and `/family` both open the window.

### Two characters — the thing Family is for
- [ ] Log to a second character on the same realm. The first appears, with its own numbers.
- [ ] Its bags are still right, drawn from storage rather than from the live client.
- [ ] A tooltip on an item held by the first character names them while you are on the
      second.
- [ ] Realms and sides are held apart on every column set.

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
| | | | | |
