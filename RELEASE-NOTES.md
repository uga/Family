## 4.4.0 — 2026-09-23

### Herbs and ore in the world

- **Hovering a herb or a mining vein in the world says who in your family already has some.**
  Point at a Silverleaf or an Iron Deposit out in the open and the game's own tooltip gains the
  possessions block, the same one that herb or that ore gets in your bags. It answers **none**
  when nobody has any, which is usually the answer you wanted. A vein's block names the ore, so
  you can see at a glance that twenty under a Copper Vein means twenty Copper Ore.
- **It works whatever language you play in**, because every word it matches is one your own
  client gave it. A vein it cannot place with confidence stays quiet instead of naming the wrong
  metal. Thorium and khorium veins are told apart, which took a second look: their names share
  seven letters and each was silencing the other on Burning Crusade and on Mists.
- **You do not need the profession to get the answer.** A character who cannot mine an Iron
  Deposit, or whose mining is too low for it, still sees who in the family is holding iron ore -
  which is usually the character asking.
- **And the dots on your maps answer too** - the minimap and the world map both, including the
  ones GatherMate and Gatherer draw from where they remember nodes being. A zone's own label is
  left alone. A cursor covering several different nodes answers about each of them, one block per herb or ore, however many pins are
  stacked up. Herbs on a GatherMate pin answer too, which they did not at first - that addon
  writes its names in colour, and Family was reading the colour as part of the name.

### Professions

- **A profession's recipe list can no longer be wiped by opening its window.** Family sometimes read
  the window before the game had finished filling it, and saved the one recipe, or none, that it saw
  at that moment - a cook with seventy-five recipes was recorded with one. Now a list that would
  shrink by more than half is read again a moment later and saved only if the second look agrees.

### Instance lockouts

- **Family now records which instances each character is saved to, and when each lock resets.**
  They are on the summary's **Cooldowns** page, which is the old Crafting page. Crafting cooldowns
  come first, as before, then instance lockouts: each raid or dungeon once, with the characters
  saved to it underneath, their lock number, and how long until it resets. Only locks still
  running are listed, and when nobody is saved anywhere the section says so. Before, Family said
  it did not record lockouts at all.
- **A lockout is read when that character logs in**, and again after a boss dies. A character you
  have not logged in since they were saved is not listed.
- **Lockouts can be shared with a linked family**, in a category of their own. They are not sent
  unless you tick it.

### Quests already handed in

- **Hovering a quest in Family's quest lists now says which of your characters have already handed
  it in**, or that nobody in the family has yet. Useful when a chain, an attunement or a reputation
  grind comes up and you need to know who can still do it. Before, Family only knew what was in each
  quest log.
- Each character's history is read when they log in and after every quest they hand in, so a
  character you have not logged in since this update has not been read yet.

### The summary

- **Hold CTRL and click a character's name on the summary to open their possessions, or ALT to
  open their professions.** Every summary list, your own characters and a linked family's alike.
  A character who has never opened a profession window says so in chat instead of opening the
  professions page on somebody else. Hovering a name says both, in grey, at the foot of its
  tooltip.
- **Hovering a character's name on the summary now says where they logged out**, just under the
  name.
- **The worth lines say what they count**: *712 items priced at auction prices*. They used to say
  *712 at auction prices*, which left the reader to guess. The same on an item's tooltip.
- **Realm headings on the summary show their whole name again.** They had been cut short, as in
  *Pyrewood Village...*.
- **Rested experience keeps growing while a character is away.** The summary's column is now
  *Rest XP est.*: the figure recorded at logout, plus 5% of a level for every 8 hours away where
  the character was resting, or every 32 hours anywhere else, up to a level and a half.
  Pandaren fill twice as fast, up to three levels. The page's note says so. Before, the column
  showed the figure from the day the character was put away. A character not logged in since
  this update shows its old figure until its next login.
- **A currency's heading on the summary shows its whole name when you hover it**, where the
  heading had to be cut to fit, as in *Darkmoon Pri...*.
- **An instance lockout's name and difficulty fit on the Cooldowns page**:
  *Hellfire Citadel: Ramparts  Heroic* used to be cut to *Hellfire Citadel: Rampa...*.
- **The summary's Last seen column gives the age alone**: *15d*, *3h*, *yesterday*, and *shared
  15d* for a linked family's character. It used to add *ago*, and *shared 15d ago* did not fit.
- **The Cooldowns page has one line of headings per section**: *Crafting cooldowns*, *Member*,
  *Ready*, and *Instance lockouts*, *Member*, *Resets in*. The line above them used to repeat
  *Cooldown*, *Member*, *Ready*.

### Achievements

- **Family no longer breaks off with *script ran too long* while you are fighting.** On Mists of
  Pandaria it read all four thousand of your achievements again every couple of seconds during a
  raid, which is far more than the game lets an addon do at once. They are now read a little at a
  time, shortly after you arrive in the world and whenever you earn one. Progress on a
  half-finished achievement now refreshes at each loading screen instead of every few seconds,
  and nothing you can see on the Achievements page has changed.

### Typing to Family

- **`/family widetime` says what changed** for each character it lists as changed since it was
  last sent to a linked family: *Malachia (bags, zone)*, or *not known* where Family did not keep
  what it sent. Before, it gave only the name.
- **`/family scancost` says which part of reading your character costs what**, a part at a time.
  For when Family is slow, or stops with an error while you play.

### Currencies

- **Honor on Burning Crusade is recognised by the game's own number for it, not by its name.**
  A family whose characters are played on clients of different languages now sees one honor
  column that adds up, where before an English client and a French one made two columns that
  each held half the family. Characters read before this change, and not logged in since, are
  counted in the same honor column as everybody else. They used to get a second *Honor Points*
  column of their own.
