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
- [ ] **Always open on one panel**, in Options. Switch it on: a star appears on every panel in
      the strip. Click one, log out and back in, open Family: it opens there. Lock the summary
      while Activity is showing and it comes back on Activity — the harness builds that panel
      once and cannot un-build it, so **this half is only checkable here**. Click a different
      set: the star goes faint. Click the solid star: it unlocks. Switch the option off and it
      opens on the summary again, with the lock remembered for when you switch it back on.
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
- [ ] On **Summary / Activity**, click the mail figure of a character who has some. The letters
      unfold under them — sender and subject on the left, the attachments as icons on the
      right with the gold beside them — and fold away on a second click. Hovering an icon says
      what it is. A character with none is not clickable at all.
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
- [ ] **A withdrawal only reaches somebody who is there** (spec §7.1), and what is held from a
      player nobody has heard from for **fourteen days** is dropped instead. Not testable in an
      afternoon and not worth faking with a clock: what *is* checkable is that a guildmate you
      have seen today survives a login, and that your own ticked grid is still ticked after
      one — the grid is ours and must never be touched by that sweep.
- [ ] Tick four boxes one after another, then `/family guild test` on your side. It counts
      **one** message sent for the lot, not four. Ticking a grid is one decision to everybody
      else in the guild.
- [ ] A guildmate on an **older Family** still exchanges gear and talents with you, and simply
      shows no professions. Note their version in the row if you have one to test against.
- [ ] **Hover something one of their shared professions can make.** A *Guild crafters* block
      appears under your own family's, naming the player and the character of theirs that can
      make it. It works on the crafted item, not only on the pattern.
- [x] **On Mists only — settled 2026-08-30. It answers.** `/family recipes` with the smelting
      window open: `Mining: 8 recipe(s), 8 with a spell id, 8 with an item id`, and Cooking 54
      for 54, each item id resolving to the product. So *Smelt Copper* is found by hovering a
      Copper Bar, which is where most people ask. Recorded in `DATASOURCES.md` §2.
- [x] **`SetGuildBankItem` — settled on Burning Crusade 2026-08-30.** It exists and reads the
      instance: four lines for a Minor Wizard Oil with `5 Charges` on its own line. Era has no
      guild bank at all, so that client cannot be asked and does not need to be.
- [x] **Charges in the guild bank, end to end — settled on Burning Crusade 2026-08-30.** The
      remaining count is in the corner of the icon in Possessions, as it is for a bag.
      **Expect to open the tab twice** the first time it holds an item this client has never
      seen: the tooltip is empty until the item data arrives, and a vault that has been closed
      cannot be read again. Correct on the second open with nothing else done.
- [x] **End to end — settled 2026-08-30.** Hovering a Copper Bar names the miner on a *Can make
      it* block with their skill, so the ids are recorded *and* the lookup uses them. Two claims,
      both measured, on the crafted item rather than the pattern.
- [ ] **Hover a pattern a guildmate already knows** — a formula in the auction house is the
      easy case. They are named on the same block as your own characters, marked *(guild)* and
      saying *knows it*.
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

- [x] **Does this client hear its own guild announcement? — settled on Mists 2026-08-30.**
      **It does.** Alone in the guild, two announcements sent and `announcements arrived: 2
      (2 ours coming back)` on the `GUILD` channel. This file previously said the opposite,
      from runs that saw no echo — an absence read as a rule (§2.2), and the entry it came
      from is corrected in `DATASOURCES.md`.
- [x] **Era — settled 2026-08-30. It echoes.** Sole Family user in a 773-member guild: `sent 2`,
      `announcements arrived: 2 (2 ours coming back)`, `from somebody else: none`.
- [x] **Burning Crusade — settled 2026-08-30. It echoes.** `sent 2`, `announcements arrived: 2
      (2 ours coming back)`, `from somebody else: none`. **All three clients echo**, which is
      the opposite of what this file said before any of them was measured alone.

#### What actually crossed the wire — the two-sided count

`/family guild test` counts both ends of every message now, and the point of these lines is
that a silence has three different causes that used to print identically.

- [ ] **`addon messages the client handed us: N, M of them Family's`.** Run it on a character
      with other addons loaded. `N` counts every addon's traffic, `M` only ours — so `N` at 0
      means the client is handing over nothing at all, and `N` high with `M` at 0 means ours
      alone is missing. Note both numbers in the row.
- [ ] **`what the client answered to those`.** Whatever `SendAddonMessage` returned, verbatim,
      by value and type, counted per distinct answer — `2 x number 0` on Mists. **Copy it into
      `DATASOURCES.md` for each client**: nothing decodes it, and what these three clients
      answer is not known.
- [ ] **`still in Family's own queue, never handed over: N`.** Should be absent. It only
      appears when the queue has not drained, which is a fault on this side rather than on the
      channel — worth provoking once by pressing *Update now* during a fight, since bulk waits
      for combat to end.
- [ ] **The closing sentence matches the numbers.** Nothing at all handed over should send you
      to guild chat; ours arriving with no announcement among them should blame Family; and
      neither should blame the channel.
- [x] **The bracket fix, on Era — settled 2026-08-30.** The six sites changed blind on 30/8 all
      hold: the talent panel shows unspent points (51 of 51), a letter with an item and money
      records both, and tooltips render. `UnitCharacterPoints` was the one to watch, since Era
      has unspent points where Mists mostly does not.
- [x] **The bracket fix, on Burning Crusade — settled 2026-08-30.** The talent panel draws a
      full build (`59 of 59 points spent`, `specialisation 1 of 2`, three trees) and the
      currencies panel draws. **What it still does not show is a non-zero unspent count**: both
      Era's 51-of-51 and this one have nothing unspent, and `unspent` is exactly the value the
      bracket protects — but the probe settles it outright:
      `/run local r={UnitCharacterPoints("player")} print(#r, unpack(r))` answered **`1 0`**, a
      single return value. So the old form could never have failed at that site, and no
      character with points in hand is needed to prove it.
- [ ] **Watch for the silence.** Twice on 30/8, on two clients, `/family guild test` reported
      `handed us: 0` — the client passing over nothing at all, from any addon — while sends
      were succeeding. It has not reproduced since: a settled character alone in its guild
      hears its own announcement back every time, and the counter climbs with other addons'
      traffic. **Two things differed on those runs and neither is isolated:** the build was one
      commit older, and the guild was mid-churn from invites and kicks. If `handed us` is ever
      0 again on a settled character thirty seconds after a reload, stop and write down what
      had just happened to the guild — that is the measurement nobody has.

#### Names and realms — a probe, not a feature

`/family guild names`. `onHello` decides an announcement is our own by comparing bare names
with the realm stripped from both sides, so a guildmate sharing your character's name would be
read as your own echo and never answered. **Write the answers into `docs/DATASOURCES.md` §2.**

- [x] **What the client calls a character — settled on Mists 2026-08-30.** `UnitName("player")`
      answers the realm as `nil`; `UnitFullName` and `GetNormalizedRealmName` give
      `MirageRaceway`; `GetRealmName` gives `Mirage Raceway` with a space. The addon channel
      and the roster both use the normalised form, on every name including same-realm ones —
      `UnitName("player")` is the only one of them that answers bare.
- [x] **Era — settled 2026-08-30.** All three exist and answer in the same shapes as Mists;
      `GetAutoCompleteRealms` returns three realms, and all 773 roster entries carry one. So the
      connected-group widening of `Offering()` is live on Era rather than falling back.
- [x] **Burning Crusade — settled 2026-08-30.** All three exist. `GetAutoCompleteRealms`
      answers an **empty table** on a realm with no partners — the call present and the list
      empty, which is not the same as the call being absent and is now its own check.
- [ ] **Do senders carry a realm on Era and Burning Crusade?** Read `addon messages the client
      handed us: … (last from X on Y)` in `/family guild test`. On Mists they always do,
      same-realm included. If either older client sends bare names, any realm-aware comparison
      has to fall back to today's behaviour there.
- [ ] **The collision itself.** The last line says how many roster entries share this
      character's name; one is you. **Two has never been seen** — it needs a duplicate name
      inside one connected group, and whether that is even permitted is unmeasured. Note it if
      you ever see two, because that is the whole question.

#### The guild event log — a probe, not a feature

`/family guild log`. Nothing in Family reads this log; this is finding out whether it could,
because Blizzard records who left a guild and that is a second source for the one departure
Family cannot otherwise learn about. **Write the answers into `docs/DATASOURCES.md` §2** — the
whole point is that they stop being recollection.

- [ ] **Run it on all three clients.** Does the client have `QueryGuildEventLog`,
      `GetNumGuildEvents` and `GetGuildEventInfo` at all? A *no* on Era ends the idea: a
      source two clients out of three lack is not a source.
- [ ] **Run it as a rank-and-file member and as an officer**, on the same guild, and compare.
      If only officers see entries, the log cannot settle anything — everyone has to reach the
      same conclusion or the guild disagrees about who is in it.
- [ ] **Copy the `[n]` lines verbatim.** They are every value the call returned, by position
      and type, and the position of the date fields and of the event word is exactly what is
      not known.
- [ ] **How far back does it reach?** On Era it is capped at exactly 100 entries and the
      *first* index is the oldest — the last four numbers on each row are how long ago, not a
      date, so the rows say which end is which. Check that on the other two clients rather
      than assuming Era's answer; and note the reach in the row, because a busy guild fills
      100 entries in days and a fortnight away then means the event has gone.
- [x] **Ordering — settled 2026-08-30.** Oldest first, measured in a guild made for it: a
      character was taken out of the guild, invited and joined, in that order and by hand, and
      the log came back `[1] quit`, `[2] invite`, `[3] join`. No need to run it a day apart.
- [x] **What a deletion looks like — settled 2026-08-30.** It produces a `quit`, exactly as
      leaving does, and the client says "X left the guild" in chat. There is a trace, which is
      what the probe was opened to find out.
- [x] **A kick is a `remove` — settled 2026-08-30**, and it names the departed in position 3
      where `quit` names them in position 2. Position 2 on a `remove` is whoever did the
      kicking, so reading it the way `quit` allows concludes that the guild master left.

#### Cooldowns, with a guildmate

- [ ] **Have them use a daily craft** — a transmute, a bolt of mooncloth, a salt shaker — with
      the profession window open, and leave it open a moment. Hover what it makes on your side:
      their line now reads *ready in Xh* rather than the age alone, and the time counts down as
      you rehover.
- [ ] **Neither of you presses anything.** Using it is what starts the timer and opening the
      window is what tells the guild, so a cooldown that has just started should reach you
      within a minute of their scan.
- [ ] **A crafter who can do it now is listed above one who cannot**, on the tooltip and in the
      whole-family search alike.
- [ ] **A guildmate's line still says how old the answer is** — the *ready* and the *4h ago*
      both, not one instead of the other.
- [ ] **Family says nothing about a cooldown it has never watched run.** A transmute nobody has
      used since installing Family carries no state at all: that is right, not a fault.
- [ ] **An item's own cooldown** — a salt shaker or a mana stone rather than a recipe — is shown
      while it counts down and disappears entirely once it comes back, rather than turning into
      *ready now*. This is the one line here that is a claim Family refuses to make, so it is
      worth waiting out a short one to see.

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
- [ ] **Press *Update now* on a linked family with nobody online.** Family names each of their
      characters once as it tries them, and says *none of them is online* once at the end —
      not four times over, and not four rounds of the game's own "no player named …".
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
| v1.2.0 | Anniversary | 31/8/26 | Alberto | Pass |
| v1.2.0 | Era | 31/8/26 | Alberto | Pass |
| v1.2.0 | Mists | 31/8/26 | Alberto | Pass |

*Client* is `Era`, `Anniversary` or `Mists` — the three the `.toc` names. *Result* is `pass`, or what was not run and
why — the sections needing a guildmate or a second family are the ones that will honestly say
so. The version cell may carry the `v` or leave it off; `release.sh` reads either.
