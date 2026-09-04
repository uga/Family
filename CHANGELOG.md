# Family — changes

What changed in each release, in the words a player needs rather than the words a commit
message uses. `tools/release.sh` cuts the top section into `RELEASE-NOTES.md`, which is the
file CurseForge shows - this whole one is history and is not published.

A player knows nothing about how Family is built and should not have to. No mechanism, no
internal names, no reasoning about how something came to be wrong, no lessons learned: an entry
says what the addon now does, and what it used to do only where that is what the reader
noticed. Everything else belongs in the commit, in `DECISIONS.md` or in `LESSONS.md`, all three
of which exist so that none of it has to be here.

Newest first. Anything under **Unreleased** is written as it lands, so that cutting a release
is a decision rather than an afternoon of archaeology.

---

## Unreleased

### Added

- **The summary can be filtered.** A box to type a name into, a class to pick, and a level
  range, on their own row above the columns. They work on whichever set of columns you are
  looking at and narrow what that set already shows rather than replacing it - so a name typed
  on Crafting still only lists members with a cooldown running. The panel says how many
  members it is hiding while a filter is on, so a short list is never mistaken for a lost one.
  Nothing is remembered between sessions: the filters start empty every time you log in.

- **Family has an icon in the game's addon list.** Both halves showed the red question mark
  the game uses for an addon that offers no picture of itself, in a list where most things
  around them had one. They now carry the same mark as the minimap button.

### Fixed

- **A shared character's mail expiry and auction age never arrived.** Wide Family named two of
  the figures it shares by the wrong name - one letter out in each - so a link that granted Mail
  sent the letters and the count but never *when they expire*, and a link that granted Auctions
  never sent how old the snapshot was. Both sides looked like they were working. They now
  arrive; a character you already share updates the next time they are seen.

### Changed

- **Family's minimap button now joins the button collectors.** Addons that gather minimap
  buttons into a bag or a bar could not pick Family's up, because it was built by hand rather
  than registered the way those collectors look for. Family now registers it where the game
  can take it, keeping the button wherever you had dragged it. Where nothing in your game
  offers that, the button is exactly the one that was there before. Nothing new is downloaded
  either way.

  Turning the button off still turns it off. Some of these bars keep a button once they have
  taken it and will not give it back, so Family hands nothing over at all while the setting is
  off - and if you switch it off while such a bar is already holding the button, Family says so
  rather than leaving you looking at a tick box that appears to do nothing.

## 1.4.3 — 2026-09-03

### Fixed

- **A salt shaker said it was ready in 49 days.** Its cooldown is three. At login the client
  can answer a cooldown question with a start time that has not settled yet, and Family wrote
  down what it was told. It now refuses an answer that says a cooldown has more time left than
  it lasts, and the next scan records the real one.

- **Miners were shown a mining cooldown that does not exist.** A Gold Bar is smelted by a miner
  and transmuted by an alchemist, and only the alchemist waits — but Family could not tell the
  two apart, so any miner who could smelt gold or truesilver grew a Mining column on the
  Crafting panel that said *ready* for ever. It now asks which profession made the thing, not
  only what was made. The wrong mark already on your characters clears itself the next time
  that profession's window is opened.

## 1.4.2 — 2026-09-02

### Fixed

- **A linked family could only be reached on the characters it had already written from.**
  Anybody they created after linking showed up on the Wide Family panel and could be ticked
  and read, but an update would never whisper them — so with only that character online,
  Family said none of the family was, and sent nothing. Any of their characters now answers
  for all of them, which is what a link to a family was always meant to mean.

## 1.4.1 — 2026-09-01

### Fixed

- **Wide Family and Guild share could not send anything, on every version so far.** Both said
  *this client has no serialisation libraries* and stopped there. The two libraries they need
  were in the download all along, in a folder one level deeper than Family looks — so a
  CurseForge install had them on disk and never loaded them. Anybody who has been unable to
  link two families, or to share a profession with a guild, was hitting this and not doing
  anything wrong.

## 1.4.0 — 2026-08-31

### Fixed

- **An enchanter who already knew a formula was offered it as one to learn.** Family matched
  recipes by name, and the trade skill window abbreviates where the item does not — so nothing
  in enchanting ever matched. It now matches on the spell the formula teaches, which is a
  number and the same in every language.

- **And the same fault everywhere else it could bite.** Whether a pattern is one you already
  know is now settled by two numbers rather than by a word: the recipe it teaches, and the
  thing that recipe makes. Whichever of the two your client wrote down is the one Family asks
  by, so a recipe list read on one language's client is recognised on another's — on your own
  characters and on your guildmates' shared lists alike. Names are still read for the few
  recipes neither number is known for.

### Added

- **Crafting column headings are in your language.** A recipe recorded on a French client was
  headed with its French name on an English one, beside columns that were in English. They are
  now named from the ids Family stores, so a family played across clients reads as one.

- **Only real crafting cooldowns are on the Crafting panel.** Things that have a cooldown and
  make something — a Chronoboon Displacer, a Super Snapper FX, a SnowMaster 9000 — were being
  listed there. A cooldown belongs on that panel when a profession makes the item and another
  recipe uses what it produces, and the wait is at least six hours — which means the Salt
  Shaker on Classic Era and Burning Crusade, and nothing at all on Mists. It has a cooldown and
  makes something, but no profession makes it, so it has no business on that panel.

- **A transmute shows up before you have ever been caught doing one.** Family used to learn
  that a recipe had a cooldown only by watching one run, so an alchemist who had never
  transmuted while Family was watching was simply absent from the Crafting panel. It now knows
  from the game's own data which recipes have a cooldown, and how long, on the client you are
  playing.

- **Crafting only lists characters who actually have a cooldown.** It used to give every
  member a row, so a family of thirty with three alchemists was twenty-seven empty lines.

- **A character who can make something two ways was listed twice.** A Truesilver Bar is
  smelted by a miner and transmuted by an alchemist, so anyone with both trades appeared twice
  on the item's tooltip — which inflated the count and pushed somebody else off the end of the
  list. Gold and several Burning Crusade reagents are made two ways as well.

- **A character's salt shaker shows on Crafting without having been caught mid-cooldown.**
  Family used to need to have seen one counting down before it would mention it at all, so a
  character could be named on the item's own tooltip as able to make one while the panel said
  nothing about them.

- **The Crafting panel shows what is ready, not only what is waiting.** A salt shaker or
  anything else with a cooldown of its own vanished from the panel the moment it became
  usable, which is precisely when you want to see it. Family still says nothing about it at
  login, because an item can be used without Family ever seeing it happen.

- **Something you buy out at the auction house counts as being in the post.** It arrives by
  mail just as a parcel from an alt does, so it now shows the same way — the buyer's mail count
  goes up straight away, and the item is listed as on its way until they open their mailbox. If
  the buyout does not go through, nothing is recorded. Winning a bid at its natural end cannot
  be shown this way, because it happens hours later while you are logged out.

## 1.3.0 — 2026-08-31

### Added

- **The hover tooltip fits the screen, however many characters you have.** With a large family
  it used to run off the top and the bottom, taking the totals and the warnings with it. The
  realm totals, the grand total and the warnings are now always shown; the character list takes
  whatever room is left on your screen, richest first, and says how many it left out. A family
  that already fitted looks exactly as it did.

- **Family knows about profession specialisations.** An armoursmith cannot make a sword and a
  goblin engineer cannot make a gnomish one, and Family used to tell you they could. Recipes
  that need a branch now say which branch, and characters on a different one are no longer
  offered as able to learn them. Blacksmithing, Leatherworking and Engineering on Classic Era,
  those plus Tailoring on Burning Crusade, and Engineering on Mists. A character you have not
  played since this version says it does not know rather than guessing.

### Fixed

- **The hover tooltip's grand total disagreed with the realms above it.** If you had changed
  what the money counts, the tooltip still listed every character on every realm but totalled
  only what the bar was counting. The total is now the sum of what it just listed; the line
  near the bottom still says what the bar itself is counting.

- **Things made by using an item now say who can make them.** Refined Deeprock Salt comes out
  of a Salt Shaker rather than off a recipe list, so its tooltip used to say who already had
  some and nothing about who could make more. It now names whoever owns the shaker *and* has
  the profession to use it, and says whether theirs is ready or when it comes back.

- **The transmute column on Crafting was headed `?`.** Any column standing for more than one
  recipe on a shared timer had no heading at all — it now carries the profession's name, in
  your language.

- **Family said your characters could learn recipes they already knew.** It matched a recipe to
  the thing it makes by name, and a recipe book does not capitalise that name the way the item
  itself does — so a Potion de Purification you learnt years ago was offered as one to learn.
  This was worst in Spanish and Russian, where it affected very nearly every recipe in the
  game, and rare in English and absent in German, which is why it lasted so long.

## 1.2.0 — 2026-08-31

### Added

- **The Guild column tells "no guild" apart from "not known".** A character who is in no guild
  now has that column left blank, and the dash is kept for characters nobody has logged into
  since Family started recording. Both looked the same before. Each character's fills in the
  next time you play them.

- **The Chrono column now says how many world buffs are trapped, and opens.** Click the figure
  and a line unfolds under the character showing which ones their Chronoboon is holding — each
  as its own icon, with the time left written on it, and the game's own description when you
  hover. Click again to close it. It used to count the boons themselves, which was always one.

- **Shift-click the minimap button or the broker bar to change what the money counts.** It
  cycles between your whole family, everyone on this side of this realm, and the character you
  are playing. The member count beside it narrows too, and hovering says which you are looking
  at. A middle click does the same. Warnings about mail expiring still cover everybody,
  wherever they are.
- **Charges are read in the guild bank too**, for the tabs you have actually opened.
- **Summary / Miscellaneous says who has a world buff banked.** A Chronoboon Displacer holding
  buffs is a different item from an empty one, so Family can tell — the column shows how many
  each character has waiting, and says it does not know for anyone whose bags it has never
  read.
- **Family shows how many charges are left on an oil.** Wizard Oil, Mana Oil, a Bag of Marbles
  — anything used a fixed number of times now carries its remaining count from your bags and
  your bank, and Possessions draws it in the corner of the icon where the game itself puts it.
  The guild bank is not read yet.
- **Characters on a connected realm are shared with your guild.** If your guild spans connected
  realms — most do — Family only ever offered the characters on the realm you were standing on.
  The rest were in the guild, listed by the game, and invisible in Family. What you had already
  ticked for them is kept and takes effect now.
- **`/family guild test` says when your announcements are not leaving.** A character on a realm
  other than the guild's own can hear the guild and cannot speak to it — the game's doing, not
  Family's. It used to look like a broken channel. It now says so, and says that what you share
  still reaches anybody who says hello first.
- **Guild records from somebody nobody has heard from in two weeks are dropped.** If a
  guildmate turns a profession off and then stops playing, the message that says so has nobody
  to reach — so what they last shared would otherwise stay answerable on your client for ever.
  It now expires, and rebuilds itself the moment they come back. Your own sharing grid is
  untouched.
- **`/family guild` says whether anything is reaching your client at all.** When two people in
  a guild cannot see each other, the report used to end the same way whether the messages were
  never arriving or were arriving and being dropped — and those need looking at in opposite
  places. It now counts the addon messages your client hands over, every addon's and Family's
  own, and says which of the two is happening.
- **`/family guild` also says what your client did with what Family sent it.** The count of
  messages sent was a count of messages Family had *written*, which is not the same as messages
  that went: one your client refused, and one still waiting in the queue, both looked exactly
  like one that had gone.
- **Joining a guild tells the guild you are there.** The announcement was made five seconds
  after you joined and abandoned if your client had not yet named the guild — which just after
  joining is most of the time. So a character who had joined, and was standing in the guild,
  stayed unknown to everybody in it until their next login. It now waits until the client can
  answer.
- **A character in a brand-new guild is recorded as being in it.** If your client was slow to
  name the guild — which it often is just after one is created — Family gave up asking and did
  not try again until your next login. The character stayed recorded as being in no guild, so it
  was missing from everything guild share does while the panel beside it listed you from the
  game's own roster.
- **Switching guild share on now tells your guild you are there.** It used to write the setting
  and say nothing, so you stayed listed as *not running Family* on everybody's Guild panel until
  your next login — even with both of you switched on and both online. Switching it off still
  says nothing, which is the point of switching it off.
- **The guild grid only offers professions that make something.** Fishing, Herbalism, Skinning,
  First Aid and Archaeology no longer get a tick box: guild crafters answers *who can make
  this*, and a profession that makes nothing has no answer to give. Mining keeps its box, for
  the smelting.
- **The Options panel scrolls.** It had grown past the bottom of the window: the last caption
  was drawn over the version line and anything below that was not on the screen at all. The
  switches now scroll — with the mouse wheel, not only the bar — and the version line stays
  pinned where it was.
- **Spanish and Russian now call things what the game calls them.** Family's own text names a
  few things from the game — mooncloth, salt shakers, mageweave — and those names had been
  translated by hand rather than taken from the game. Spanish called mooncloth *paño lunar* and
  mageweave *tela mágica*; Russian called mooncloth *лунная ткань*. None of those is what you
  see on your own screen. They are now read from the client's own tables, in every language.
- **A switch for Wide Family's chat reports.** Options, under the Wide Family switch. A link
  to a family whose one character is rarely online says *nobody was there, nothing was sent*
  every time it tries, which is the answer the first time and noise by the tenth. Turn it off
  and the line stops; turn on *Narrate what the scanners are doing* and it is still there if
  you want it.

  It governs that report and nothing else. Somebody asking to link, a link made or ended, and
  anything that has gone wrong are always said.
- **Guild crafters now say whose cooldown is up.** Hover a transmute, a bolt of mooncloth or
  anything else on a daily timer and the people who can make it are listed with the state of
  their timer beside them — *ready now*, or *ready in 4h* — and whoever can do it now is
  listed first. Your own characters and your guildmates alike, on the item's tooltip and in
  the whole-family recipe search.

  A guildmate's line still says how long ago you heard from them, because that is how old the
  answer is.

  Two things Family will not claim. It says nothing about a cooldown it has never watched
  running, because until then there is no way to tell a transmute from a bandage. And where a
  cooldown lives on an item in somebody's bags rather than on a recipe, it is shown only while
  it is still counting down — once it comes back Family has no way of knowing whether it has
  been used again, so it stops saying anything.
- **Click the mail figure on Activity to see what is waiting.** The number said how much and
  never what. It now unfolds under that character, a line per letter: who it is from and what
  it is called on the left, **what is attached to it as icons on the right** — hover one to
  see what it is — with the gold beside them, cash on delivery in red, and how long that
  letter has left. Click it again to fold it away.
- **Family can be locked to one panel.** A new switch in Options puts a star beside every
  panel in the strip. Click one and Family opens there every time, now and after you log out.
  The star is solid on the panel it is locked to and faint everywhere else, and clicking the
  solid one unlocks it again.

  On the summary the lock takes the set of columns you are looking at with it, so it can mean
  *Activity* rather than the whole panel. To move it, go to another set and click the star
  again — it goes faint the moment the columns change, which is what says it can be moved.

  Off unless you ask for it, and walking to another panel never moves the lock: only clicking
  a star does.


- **You can now show your guild what your characters can craft, one profession at a time.**
  The Guild tab has a grid of your characters who are in the guild and the professions each of
  them has, and nothing is shared until you tick a box. A guildmate running Family then sees
  that profession and its skill level beside that character of yours. Untick a box and it
  stops being sent; what they already hold is replaced the next time they hear from you,
  without either of you pressing anything.

  This is the first part of it, and it carries skill levels rather than recipe lists. A skill
  level says somebody might know a pattern. It never says they do.

  Guild share itself is still off until you switch it on in Options, and the grid is greyed
  and says so until you do.

  The grid starts **folded**, because the Guild tab is about the guild's people and a player
  with eight characters in it has thirty rows of grid above the roster. Its heading says how
  much you are offering while it is folded, and one click opens it.

- **The panel counts people rather than characters.** "9 running Family" in a guild where
  eight of those nine were your own alts is not an answer to the question that number is
  there to ask. Your characters count as one — you.

### Fixed

- **Opened mail no longer follows you to another panel.** Clicking the mail count on Activity
  unfolded the letters, and they stayed on screen after switching to Currencies or any other
  panel, under members that had nothing to do with them.
- **And the game itself says it far less.** Reaching somebody who is not there produced one
  red *"No player named …"* from the game for every message that had already been sent — four
  per character, twenty for a family of five, and none of them Family's to take back. Family
  now sends one message to somebody it has not just heard from and waits a moment before
  sending anything else, so a character who is not there costs one line instead of four.
- **Trying to reach a linked family who is offline is quiet now.** It used to walk that
  family's characters four times over — twenty attempts for a family of five, four copies of
  every line Family printed, and twenty refusals from the game. It answers the first refusal
  and ignores the rest, which is the same news arriving again; and the lines naming each
  character as it tries them have gone from the chat frame, because the working is not the
  answer. What is left is the one sentence saying nobody was there. Switch on *Narrate what
  the scanners are doing* in Options to see the working.


- **"Which guildie can craft this?" now has an answer.** A profession you share with the guild
  carries what it can make, and a guildmate running Family sees it in two places: on the
  item's own tooltip, under the crafters from your own family, and in the recipe search on the
  Professions panel, as a second group beside your own. One box, one question, two sources.

  The answer names the **character** that can make it. Everything shared this way is a
  character in your guild, so it is on the roster you already have: whisper it if it is
  online, and see that it is not if it is not.

  Nothing but identifiers crosses, so a recipe list read on a French client is found by
  somebody typing German, and neither of you has ever held a word the other could read. A
  recipe your client gives no identifier for is not shared, and the panel says how many were
  left out rather than implying the list is complete.

  It is carried once. Each shared profession sends how many recipes it has and a fingerprint
  of them, and the list itself is asked for only when that differs from what the other end
  already holds — so a settled guild costs nothing after the day everybody met. Untick a
  profession and the list goes with it, on their side as well as yours, without either of you
  pressing anything.

- **A pattern now says which of your guildmates already knows it.** A guildmate's shared list
  *is* the list of recipes they know, so a formula one of them is holding is one you may not
  need to buy — you can ask instead. It sits on the same block that says which of your own
  characters know it or could learn it.
- **Hovering something craftable now says who can make another one — yours as well as your
  guild's, in one block.** A pattern still gets the other answer instead: who knows that
  recipe and who could learn it. They are two questions about two different items — the plans,
  and the thing the plans make — and neither is now answered on the other's tooltip. It only ever said who *owned* one. The block that names crafters
  answers about a *pattern* — who knows it, who could learn it — and finds people by the
  subtype and skill written on a pattern's tooltip, which the thing it makes does not carry.
  So the robe told you who had one and nothing about who could make another; and once guild
  crafters arrived it named a guildmate who could while staying silent about the character in
  your own list.
- **Enchanting answers on tooltips too.** An enchanting recipe carries the spell it is and,
  on Classic Era, nothing else — the game gives no id for the thing it makes, even for the
  ones that make something. So no id on the oil under your cursor, or on the formula that
  teaches it, could ever match, and enchanting was the one profession that answered nothing.
  Family now also recognises them by what **your own** client calls them, which is how the
  crafters from your own family have always been found.
- **A recipe only somebody in the guild knows now has its picture**, instead of a question
  mark. A picture is not an identifier and does not cross, so there was nothing to draw until
  Family started asking its own client for one.
- **The list of who can make a recipe no longer runs off the right of the panel, and nobody is
  hidden by it.** It shows the four highest-skilled and counts the rest, and **clicking the row
  unfolds every one of them** — your characters with their skill, and your guildmates with how
  old the record is. Clicking again folds it away.

  The four it shows are the four you would actually ask: sorted by skill rather than by name,
  so what the count hides is the people you would ask last.
- **Shared recipes now work on Classic Era.** A recipe was carried as the spell it is, and on
  Era the game does not give a spell for trade skill recipes at all — it gives the item each
  one makes. So a guild on Era shared nothing but enchanting, which is the one thing there
  with a spell and no item. A recipe now travels with whichever identifier your client gives
  it, and with both where it gives both.
- **A profession with nothing to share no longer advertises an empty list.** One whose window
  came back with no recipes still announced a count and a fingerprint of nothing, which the
  other end asked about and received nothing for — showing up as *4 lists, 0 recipes in all*.
- **`/family guild test` says how many of the recipes you hold carry the id of what they make.**
  A recipe with only its spell can answer on the pattern and never on the food, so a guild
  whose lists are all spell and no item looks exactly like a guild whose lists never arrived.
- **A guildmate who was offline when you shared something now gets it as soon as they log in.**
  Two clients that had spoken to each other in the last six hours exchanged nothing further,
  which is what keeps a settled guild quiet — but it also meant that anything you shared while
  somebody was logged off waited out those six hours. Each announcement now carries a single
  number saying what you are offering, so a client that has less than that asks for it at once
  and one that already has it stays quiet.
- **The recipe search says whether it looked at your guild**, and says that it could when guild
  share is off. It is labelled *whole family*, and nothing about it revealed that it had grown.
- **The guild list's right-hand column no longer cuts off how old a record is** — `8 characters
  || 1h...` was losing the one thing that says how much to trust the other two.
- **Opening a shared profession's window now tells the guild there is something new to send.**
  Ticking a profession you had never opened shared a skill level and nothing else, and opening
  it afterwards changed nothing anybody could see: no box had moved, so nothing was announced,
  and both ends went on holding recent gear and talents in silence. The recipe list never
  crossed.
- **Update now means it.** It used to send an ordinary announcement, which the other end is
  entitled to answer with "nothing has changed" — so the one button you press because you
  think what you are looking at is stale could do nothing at all, and look no different from
  one that is broken.
- **Professions recorded before Family kept track of them by identity can now be shared.**
  A character last played a while ago had its professions filed under their names, and the grid
  would not offer any of them — it said the character had no professions at all, while the line
  beneath it listed them by name. They are offered now, and that line is left only for the ones
  the client really gave no identifier for.
- **A character could end up with no guild recorded at all**, and then behave as though they
  had never been in one: missing from the grid of what you share, and shown as *not running
  Family* on your own guild roster, while looking perfectly ordinary everywhere else in
  Family. The game does not answer which guild you are in for the first few seconds of a
  session, and Family took no answer for an answer. It now waits for the client and asks
  again. **Log in once on any character this happened to and it fills itself in.**
- **A character who leaves a guild is no longer recorded as still being in it.**
- **`/family guild test` now lists any of your characters with no guild recorded**, so the
  cause is something you can read rather than something you have to guess at.
- **A profession whose window opened and showed nothing no longer reads as never opened.**
  Those are two different things and the panel now says which it saw — and, when a profession
  that makes things lists nothing, names the likeliest reason: another addon filtering or
  replacing that window. That distinction is the difference between a diagnosis and an
  evening.
- **A profession window with its categories folded up is now read in full.** The window lists
  only the rows it is showing, so a collapsed heading hid every recipe under it and the scan
  came away with nothing — the same trap Family has avoided in the skill list since it was
  written, in the one window the recipes are actually in. It is unfolded, read, and folded
  back exactly as it was found.
- **A link request to a second character of a family you are already linked with no longer
  waits for ever.** Ask two characters of the same family, link through the first, and the
  request to the second used to sit on the Wide Family panel saying *waiting for them to
  answer* — about a link you already had. Their copy of Family recognised the situation and
  said nothing back; it now answers, and the request clears itself. Hearing from that family
  at all clears it too, so an older copy on the other end costs you nothing.
- **Leaving a guild now clears what that guild had shared with you**, and what you had offered
  it. It used to stay out of sight on disk and come back out of date if you ever rejoined.

## 1.1.0 — 2026-08-29

### Fixed

- **Where a hearthstone is bound now reads in your own words.** A character last played on a
  Classic Era client showed "Ironforge" to a French player whose own client calls it
  "Forgefer" — the two expansions disagree even in the same language. Family now records which
  place it is rather than what that client called it, and each member is named by the client
  you are reading on. A member keeps its old spelling until you next log into them.

- **The lists you pick from are no longer see-through.** The panel underneath showed through
  them, so a character's name and a recipe's name were drawn on top of each other and neither
  could be read. This was the member list, and the realm and class lists on the character
  panel.
- **Members shared by a linked family are now listed under the realm they are on**, not in one
  undivided run of names. A family with thirty characters across three realms was impossible to
  read, and two characters with the same name on different realms could not be told apart.
- **Each heading in that list has room above it**, so a section begins instead of continuing.
- **The Wide Family panel lists members under their realm and faction**, on both sides — the
  characters you are sharing and the ones a linked family shares with you. A family of thirty
  arrived as one undivided column of names with nothing saying which realm a row was on, and
  two characters with the same name could not be told apart at all.
- **The list of what a linked family shares with you is now in a stable order.** It had none,
  so it could rearrange itself between refreshes.
- **Panels no longer draw themselves squashed the first time they are opened.** On the Guild
  panel a guildmate's name, rank and item level were written over one another in the same
  place, and closing the window and opening it again appeared to fix it. The same fault was
  waiting on every other panel that draws a list. All of them are drawn at their proper width
  the first time now.
- **The summary no longer complains in the chat frame every time it is drawn.** Its row of
  column-set buttons was four pixels wider than the room it had, in English, and said so on
  every draw. The buttons now sit a pixel closer together.

## 1.0.0 — 2026-08-29

Family records what each of your characters owns and knows, and shows it to you while you are
logged in on a different one. It starts empty and fills as you play: a character appears the
first time you log in on them, and a family of ten takes ten logins to be complete.

Everything it holds, it holds because it watched it happen. There is no import from another
addon, nothing is fetched from a server, and every screen says how old what it is showing is —
because a number with no date on it is a guess wearing a fact's clothes.

### What it shows you

- **A summary of the whole family**, a row each, with the columns you choose: level and item
  level, money, rested experience, time played, bags and bank space, mail and what is about to
  expire, auctions and what is riding on them, professions and their ranks, currencies,
  crafting cooldowns, guild, hearthstone, race and class.
- **Possessions** — one character's bags, bank, mailbox, auctions and guild bank, drawn as the
  containers themselves rather than as a list, because where a thing sits is information.
- **Professions**, with every recipe each character knows, sorted by difficulty, by the item
  level of what it makes, or by the skill it needs. Search the whole family for a recipe and
  it tells you who can make it.
- **Abilities and talents** — both specialisations, drawn as the tree they actually are, with
  glyphs and the spellbook.
- **Character** — gear with item levels, reputations, played time, experience.
- **On every item tooltip in the game**: who in the family has one and where it is, and on a
  recipe, who can make it, who could learn it today, and who is not high enough yet.

### Sharing, if you want it

Both of these ship switched off, and both have a panel you can read before deciding.

- **Guild share** shows your guild the gear and talents of your characters in it, and shows
  you theirs. Nothing else — and nothing that Inspect does not already give away.
- **Wide Family** links two families that are not one account. Each of you says what the other
  may see, one character and one category at a time, on a grid that starts with nothing
  ticked. Nothing is exchanged until both of you agree, and either of you can end it.

### In your language

English, German, French, Spanish and Russian, following whatever your client is set to. Where
the game already has a word for something — a gear slot, a class, a profession, a race, a
talent — Family uses the game's own word, so it says what the rest of your interface says. A
character recorded on somebody else's client, in a language you do not read, still reads in
yours.

### Fixed since the last beta

- **The bank is drawn as a bank** on Possessions, rather than as another bag.

- **A bank record can no longer be replaced by an empty one.** Family could scan a bank that
  was not in front of it — the game answers about the bank whether or not you are standing at
  one — and the result was a tidy record of an empty bank written over a real one. If a
  character's bank has gone blank, open a bank on them once and it comes back; nothing was ever
  lost from the game itself.
- **The free space in a bank is counted rather than asked for.** The game reports four more
  free slots than a bank has, so a full bank could read *4 free* and an empty one could total
  more free slots than it has room for. Visit a bank once on each character and the figure
  corrects itself.

### Upgrading from a beta

Open each profession window once per character. Nothing else needs doing, and nothing is lost
if you do not.

## 1.0.0-beta.3 — 2026-08-28

### Added

- **Family speaks German, French, Spanish and Russian.** Every screen, every slash command,
  every message it prints, and the manual on the About tab. Where the game already has a word
  for something — a gear slot, a class, a reputation standing, a profession, a race — Family
  uses the game's own word, so it says what the rest of your interface says.
- **Mail on its way has a column of its own** in the Activity set, beside the mailbox count,
  and it no longer waits for a mailbox to have been looked at before it will tell you.
- **Nothing is cut off in a longer language.** Columns and buttons are measured against the
  words actually in them and widened where they need it.

### Fixed

- **Professions, races and recipes are shown in your language, whoever recorded them.** A
  character last played on a French client used to stay French on a Spanish one, and a member
  shared with you was named in whatever their owner was running. Races and recipes need
  nothing from you. **Professions want one rescan** — open each profession window once per
  character, which also puts their recipe lists right.
- **A recipe list no longer arrives half translated.** The rest of it fills in as your client
  loads the items, rather than staying in the language it was written down in.
- **The undead are undead.** Where Family had no word for a race it showed an internal one —
  *Scourge*, *NightElf* — that the game shows nobody.
- **A guildmate who is running Family is no longer listed as not running it.** Family knows
  somebody runs it by hearing from them, and a client that already had your characters used to
  answer your announcement with silence. It says hello back now. This showed up most for
  anyone who had cleared their saved data or reinstalled, whose guild then looked empty.
- **The professions panel names the profession above the recipe list**, rather than a number.
- **A recipe you click with no profession window open stays marked** until you open one, and
  the message names the button that opens it. It used to tell you which button to press and
  then lose the recipe you had picked.
- **A profession with no recipes is no longer reported as recorded in another language.**
  Fishing, herbalism, mining and skinning have no window to open.
- **The line saying which professions are missing from the list now wraps** instead of running
  off the right edge.
- **The minimap total agrees with the tooltip under it.** The figure on the bar was worked out
  once at login, so it drifted by however much you had spent since.
- **Dates take less room.** *19 days ago* is now *19d ago*, matching the *in 19d* the columns
  beside it already used.

### Changed

- **The minimap tooltip groups characters by realm and then by side.** An Alliance character
  and a Horde one on the same realm share no bank, no mailbox and no auction house, and a
  single list of them read as one pool of characters that could pass things between them. Each
  side now carries its own count and its own money, the way the summary has always shown it.
- **Anything Family counts is phrased for the language it is in**, rather than by adding an
  "s" to a word.
- **Wide Family is described as what it is: off by default.** It shipped with a warning that
  none of its checks had run against a real server; that pass has since run on all three
  clients. It is still off until you ask for it — sharing is the one thing a later version
  cannot take back — but that is a choice about consent now rather than a caveat about
  testing.

## 1.0.0-beta.2 — 2026-08-27

### Fixed

- **The Wide Family grid's column headings no longer overlap.** "Sibling  Member", above a
  linked family's shared characters, was drawn through the first category column beside it.
- **A sibling's *Last seen* says when they were last shared.** It was a dash: when somebody
  else's character last played is not something that crosses the wire, so the column had
  nothing of its own to say. It now answers the question it can — how old what you hold about
  them is — written as *shared 2 h ago*, so a date with no word beside it is still your own
  family's sighting and one that says *shared* came from theirs.

- **A realm with characters on both sides reads as two groups again.** The second side's
  heading sat one line under the first side's subtotal, and the realm's own total sat one
  line under the last side's — so a screen of numbers ran together with no telling which
  figures belonged to whom. Both now have a line's space above them, on every column set.
- **Possessions no longer looks broken when you switch to the whole family.** That mode has
  nothing to draw until you type something, but the caption over the box still read "dim
  everything but" — over a panel with nothing left on it to dim. It now says what the box is
  for, and the cursor goes into it. Professions says the same thing in the same way.
- **Everyone's gear is split by side, the way the summary is.** A row on that screen is a
  class picture and nineteen slots, and the only place it said which side its character was on
  was the tooltip of the picture — so a family with one Horde character in it looked like a
  family that had lost them. Alliance and Horde now get a heading each, with a count, whenever
  there are both to tell apart.

## 1.0.0-beta.1 — 2026-08-26

### Added

- **The whole family on one screen.** Every character you have played, grouped by realm and
  by side, with money, bags, professions, currencies and the rest — and totals per realm.
- **Possessions**, drawn as the bags themselves rather than as a list. Clicking an item opens
  the bag it is in, when it is the character you are playing.
- **Professions**, with three sort orders, and clicking a recipe finds it in the open window.
- **Abilities and talents**, both specialisations, glyphs and the spellbook.
- **Character**: equipped gear laid out as the character sheet lays it out, with the enchants
  and gems on it, plus currencies, reputations, the quest log and achievements.
- **Family on the game's own item tooltips**: who has one and where it is, and on a recipe,
  who can make it, who can learn it today and who is not high enough yet.
- **Everyone's gear on one screen.** Character, Equipped gear, *Whole family*: one row per
  member — their class, then every slot in the order the character sheet puts them, with the
  item level over each icon and the item's own tooltip on hover. Filters on realm and class,
  each a list of what your family actually has.
  A character sheet answers *what is this character wearing*; this answers *who is behind*.
- **Mail is written down as you post it.** Send anything to one of your own characters and it
  appears against *them* straight away — the money, the attachments and all — marked as being
  in the post until that character opens their own mailbox, at which point what is really
  there replaces it.
- **Guild share.** On, and one switch turns it off. Everyone in your guild running Family
  shows their characters' gear and talents to everyone else running it, and you see theirs —
  including the ones who are offline, once you have seen them once. Talents come across as the
  shape of the build — which trees, how many points in each — rather than talent by talent,
  because whole trees for everybody's alts would take a channel Family shares with every other
  addon in the guild. Nothing else is shared: bags, mail, money and the rest need a Wide
  Family link. It is on by default because all of
  it is what the game already shows anyone who inspects you; a consent dialogue in front of
  that would teach people to click through consent dialogues.
- **Pictures on the tabs**, on the Character panel's sections, and on the summary's two side
  filters — which were the letters "A" and "H", initials that mean nothing in four of the five
  languages Family supports. Every one of them was looked at on all three clients before it
  went in, because a texture path that does not exist draws nothing and says nothing. The
  window and the tab strip are a little wider than they were, so that no label and no panel
  lost any room to the pictures in front of them.
- **Every section of the Character panel carries a picture too**, and the summary's two side
  filters are the game's own faction banners.
- **Realms split by side, where there is a split to make.** A realm with characters on both
  gets a section and a subtotal for each, because two characters on opposite sides of one
  realm share nothing this table is about — different auction house, different mail,
  different everything. A realm with one side on it is left alone.
- **Professions carry their own picture** on the buttons at the top of the Professions panel,
  wherever the client hands one over with the rank. Where it does not — the older skill list
  has no equivalent — the button reads as it always did rather than showing an invented one.
- **Each filter box now has its caption in front of it** rather than after it, and on the
  whole-family gear grid it sits beside the two filters instead of underneath them.
- **The realm and class filters are lists**, not buttons that step through the values one
  click at a time. Stepping was tolerable at three realms and unusable at eleven classes, and
  a long realm name wrote itself straight through the side of the button it was on.
- **One control for looking at everybody**, everywhere it is offered. Possessions and
  Professions had a tick box and a caption for it and Character had a button; they all have
  the button now. Switching between two ways of looking is not a setting, and it should not
  be dressed as one on two panels and not on the third.
- **Search across the whole family**, on Possessions and on Professions, saying who has what.
- **Crafting and item cooldowns**, recorded as the moment they come ready, so they stay right
  however long the client has been shut, and announced when you log in.
- **A minimap button and a data broker feed**, with the family's money on it.
- **Wide Family**, *switched off in this version*: two players link their families and each
  says what the other may see, one member and one category at a time, on a grid that starts
  with nothing ticked. Nothing is exchanged before the other side accepts, unticking a box
  asks them to forget it at once, and borrowed members are kept apart from your own.
  Exchanges happen when a linked family comes online, when you change what is shared, and on
  demand. It is complete and its checks pass, but none of those checks has run against a real
  server, and sharing is the one thing a later version cannot undo — so it waits until it has
  been proven live. `/family wide on` to help test it.
- **Siblings**, part of Wide Family and switched off with it. Among the members a linked
  family has shared with you, tick the ones worth seeing every day: they then appear in your
  summary, under their own family's name, on the realm they are on. It sends nothing and asks
  nobody — they decided you may see them before the name could appear in the list.
- **Automatic exchange can be switched off**, on the Wide Family panel. Off means nothing
  happens without a person asking for it; *Update now* stays, and always will. Withdrawing
  what somebody may see is still sent at once, because that one is a promise rather than a
  convenience.

### Fixed

- **Family had never received a single addon message.** Not one, on any client, in either
  direction, for the whole of the project's life. The handler for the game's addon-message
  event took the event's first *value* where the game passes the event's *name*, so the test
  that checks the message is Family's compared `"CHAT_MSG_ADDON"` against `"Family"` and
  dropped everything on the first line. Wide Family link requests that were never answered
  and a guild panel reading "0 running Family" were both this, and neither was a fault in
  those features. Five hundred checks missed it because every one of them handed the message
  straight to the receiver, covering the transport in detail and the one line joining it to
  the game not at all.

- **A linked family is one entry.** Its line opens to show both halves in one place: what they
  may see of your characters, and what they share of theirs with a *Sibling* tick against each.
  The separate *Shared with you* list at the foot of the panel is gone — a link is one family,
  and drawing it as two things is what left both halves fighting for the width of a row.
- **The Wide Family panel says what "automatically" means.** Under the switch is a line saying
  that coming online is the only time an exchange happens by itself, that what you each see of
  the other is as it was at the last one, and that *Update now* on a family's line brings it up
  to date. Nothing about it changed — it was already a snapshot by design (§6) — but the panel
  was letting the word "automatically" promise a freshness it never has.

- **Update reaches a family through whichever of their characters is online.** It used to
  whisper the one you heard from last and give up on being told they were not there — which is
  usually the wrong one, since a person plays one character at a time and the link may have
  been made a week ago. Family now tries the next of theirs, and the next, and only says the
  family is offline once every one of them has been eliminated. Pressing Update again then
  sends nothing rather than starting over.

- **Pressing Update on somebody who is offline really no longer floods your chat.** The first
  attempt matched the name the client complained about against the name Family whispers, and
  those are not the same string — *Grella* against *Grella-Thunderstrike* — so it dropped
  nothing and the flood carried on unchanged.
- **Pressing Update on somebody who is offline no longer floods your chat.** An exchange is
  hundreds of whispers and the client answers every one of them with *No player named X is
  currently playing*. Family now notices the first one, drops everything else queued for them,
  and says so once. Pressing it again says they are offline instead of doing it all over.

- **The Wide Family panel says what they share with you.** *Shared with you* now carries the
  same nine columns as the consent grid, greyed — so both halves of a link can be read against
  each other. The marks are what the other side said it granted rather than what happened to
  arrive, because an empty mailbox and a mailbox nobody shared send the same nothing.
- **The panel says that a linked family's line opens its grid**, which nothing did — the line
  looks like a heading rather than a button.
- **Column headings no longer touch, and a family's name no longer runs under its own summary.**

- **A sibling's things show on item tooltips.** "Who has one of these" is the question a
  shared family is most often asked, and the answer left siblings out — the item index was
  built from your own members alone. Their line says whose character it is, because a count on
  a tooltip reads as *I can go and get that*, which is not true of somebody else's bank.

- **A linked family's characters are not drawn in with your own** on Character / Equipped gear
  / *Whole family*. They were, briefly, and with no heading over them — which on that screen is
  nineteen item pictures in a row with nothing else to say whose they are.

- **Lists close when you click away from them.** The member button's list, and the realm and
  class lists, could only be closed by choosing something from them — which turns a list you
  opened to look at into a question you have to answer. Clicking anywhere else puts them away
  now, and so does Escape.

- **You can look at what a family shares without adopting them.** Abilities & Talents,
  Possessions, Professions and Character now offer everyone a linked family shares with you,
  listed under that family's name rather than filed under a realm. Making somebody a *sibling*
  goes back to meaning the one thing it was meant to mean — who belongs in your summary,
  beside your own — instead of also being the only way to see any of their records at all.

- **Money can be shared.** It always could — the switch was drawn off the end of the consent
  grid, where nobody could reach it. The grid asked for 816 pixels of a row that is about 712,
  so its last column fell off the edge and the one before it was cut in half. It shares out
  the room it has now, and says so if it ever cannot.
- **A category nobody shared reads as unknown, not as nought.** A linked family's members were
  listed on the summary as having no money, never having played, and being at maximum level —
  three facts, none of them told to us, all of them deduced from an absence. Nothing shared is
  now drawn as nothing known (§2.2).
- **Tick a whole column at once.** Clicking a category's name in the consent grid grants it for
  every member, and clicking again clears it — one decision instead of one per member, and one
  message to the other family instead of one per member.
- **The summary lines its siblings up.** A linked family's name now sits under the realm's, and
  their members under yours, rather than each a step further right; and the block is held apart
  from your own members, and the grand totals from the last realm's, by a blank line.
- **The note about sharing sits with the sharing.** It was at the foot of the panel, below the
  list of what other families share with *you*, where it read as a note about that.

- **The Wide Family panel stops drawing over itself.** The consent grid's column headings
  stayed on screen after the grid was closed and lay across the sentence below it, a borrowed
  member was cut short to "Grella of Grella-Thunder..." because the row had last been used by
  the grid and kept its narrow name column, and each link's summary ran underneath its own
  Update now and Unlink buttons. Rows are reused as the list changes shape, and they now come
  back to the panel in the state they were built in rather than wearing whatever the last
  section left on them.

- **Accept, Decline, Ask again, Forget and Unlink can be clicked.** Every button on the Wide
  Family panel drew perfectly and did nothing. They sit on top of a row that spans the whole
  width of the list, and nothing said which of the two was in front — so the game broke the
  tie by which was built first, and the first time the panel needed a row it had not built
  before, that row went in front of the buttons and started taking their clicks. The buttons
  and tick boxes are now put in front outright, and rows with nothing to click no longer take
  the mouse at all, which also stops headings from lighting up under the cursor as though
  they led somewhere.

- **"Of the Eagle" items are described as they really are.** A random-enchantment item is one
  item id wearing one of dozens of suffixes, and the suffix is where its whole stat line
  lives — so bags, bank, guild bank and mail tooltips were showing the generic item and
  "<Random enchantment>" where the stats should be. Family now keeps the extra detail for the
  items that have any, and only for those: a bag of cloth costs exactly what it always did.
  Records already on disk pick it up the next time that bag or bank is seen.
- **Your own characters count as running Family** in the guild list. Your announcement comes
  back to you off the guild channel and is correctly ignored as an echo, which had the effect
  of your own row reading *not running Family* — on the one client in the guild you can be
  certain about.
- **Guild share works across connected realms.** Messages were matched on the guild's name
  *and the sender's realm*, and two people in one guild on connected realms do not agree about
  what realm they are on — so every message was dropped and the panel read "0 running Family"
  in a guild where several people had it. Matched on the guild's name now.
- **Family gets out of the way when it sends you somewhere.** Clicking a quest, or a worn item
  on your own paper doll, opens the game's own window — which drew *behind* Family and could
  not be brought in front of it by clicking, because a higher layer always wins. Family closes
  instead; `/family` brings it back on the tab you left it on. Clicking a recipe is not one of
  these: it selects the recipe in a profession window you already had open, so Family stays
  where it is and you can click the next one.
- **Summary / Crafting**: every crafting cooldown the family has, one column per kind, green
  when it is available and grey with the time when it is not. Thirty alchemy transmutes share
  one timer and appear as one column called *Alchemy* — Family works that out by watching them
  come back together rather than from a list somebody has to keep. A salt shaker is in there
  under leatherworking, because Family knows which recipe makes it. A column appears once
  Family has seen that cooldown running at least once: the client will not say a recipe *has*
  a cooldown while it is ready, so that has to be learned.
- **Your hearthstone is no longer announced as ready.** Two faults met in one message. The
  floor for "a cooldown worth knowing about" was one minute, which let in hearthstones,
  trinkets and mana stones — it is six hours now, comfortably below anything on a daily and
  comfortably above everything that is just a cooldown. And an item's cooldown was reported as
  ready for ever once its moment passed: using an item needs no window open, so Family sees
  nothing and cannot know it has not been used ten times since. Those are dropped when they
  elapse; while they are still counting down they are kept, because that much is known. A
  crafting cooldown is different and still counts — using one needs the profession window,
  which Family scans.
- **"Crafting ready" for a profession you gave up.** Family keeps the recipe list of a
  profession you drop, which is right — take it up again and nothing is lost. It was also
  keeping that profession's cooldowns, and those never expire on their own: the entry is only
  rewritten when that profession's window is opened, and it never will be again. Cooldowns now
  come only from professions the character still has.
- **`/family ready` names what is ready** instead of counting it. "3 ready" answers a question
  nobody asked; which three is how you find one that should not be in the list.
- **Sorting recipes by difficulty orders within each colour too.** A colour is a band of four
  and nine grey recipes are not equally trivial — ordered by name inside the band, Heavy Linen
  Bandage sat above Runecloth Bandage, which is alphabetical order wearing a difficulty label.
  Inside a band it now goes by the skill each one needed, then by the item level of what it
  makes, then by name.
- **Rows that do something light up on hover**, and rows that do not, do not. A quest
  belonging to a character you are not playing cannot be opened, so it no longer offers to.
- A list opened from inside the Family window is closed with it. Both the member picker and
  the new filter lists float above the game rather than inside the panel, so hiding the panel
  never took them with it.

### Notes

- Family starts empty and fills up as you play. It imports nothing from anywhere.
- Bank, mailbox and each profession window need opening once per character — the game only
  shows their contents while they are open.
- Nothing is ever reported as empty when it was simply never seen, and every screen says how
  old what it is showing is.
