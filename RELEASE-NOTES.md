## 2.0.0 — 2026-09-06

**Your whole family on one screen.** Quests, reputations and profession cooldowns each get a
whole-family view, the summary sorts and filters on any column, and Family tells you at login
whose mail is about to expire. For Classic Era, Burning Crusade Classic and Mists of Pandaria
Classic.

### See every alt at once

- **Everybody's quests.** One line per quest with whoever has it underneath, furthest along
  first — so *who else is on this* is one look instead of forty logins.

- **Everybody's reputations.** Every character who has a standing with a faction is listed under
  it, furthest first, with their own standing and score. *Who can buy that pattern* is now a list
  of names rather than a single best score.

- **Profession cooldowns as a list, with no limit.** Each cooldown gets a line with everybody who
  has it underneath, readiest first, and how many can do it right now. The old grid could show
  four kinds of cooldown however many your family had and quietly dropped the rest.

- **The bag search reads like a list.** An item is written once with its holders under it, most
  first, and how many they have in front of where it is: **209 (62 bags, 147 bank)**. Sort by
  character instead and everything one alt is carrying is together.

### Find things faster

- **Sort the summary by any column** — money, rested experience, last seen, free bags, mail and
  when it expires, auctions, world buffs, currencies, who can craft something soonest, guild,
  hearthstone, race, class. Click again to turn it round, a third time for the panel's own order.
  Each set of columns remembers its own between sessions.

- **Filter by name, class and level range**, on their own row above the columns, on the summary
  and on the profession and bag searches. The panel says how many members a filter is hiding, so
  a short list is never mistaken for a lost one.

- **Narrow the summary to one profession or one cooldown.** *Which of my level 60s are
  blacksmiths* is one row of controls; *who is waiting on Mooncloth* is one choice.

- **A key binding for Family**, in the game's own Key Bindings window, with nothing bound to
  start with. TAB moves between filter boxes.

### Professions, weapon skills and riding

- **The Professions overview is drawn as pictures** — each trade's own icon and its rank — so a
  character's whole set of skills fits where two used to. Hover a row to read the names.

- **Specialisations are named at last.** Weaponsmith, Dragonscale Leatherworking, Goblin
  Engineer, Alchemy's masteries — listed under the profession they belong to, and a specialised
  character shows their branch's own picture instead of everybody's anvil.

- **Weapon skills have a page.** Switch the professions panel to Weapon Skills and the filter
  offers weapons — pick Swords and see who has them and who is furthest behind.

- **Riding counts as a skill**, and a rogue's lockpicking sits with cooking and first aid where
  the rest of what a character has already is.

- **CTRL swaps a recipe's tooltip on Classic Era too**, so you can see what a recipe costs to
  make rather than what it makes, on every profession.

### How fast each character gets about

- **A Mount column on the Overview**, worked out from the mount a character actually owns rather
  than from their riding skill — so class mounts and bought mounts both count.

- **It says whether they can fly**: *100%/60%* with a gryphon, *100%/-* without. Flying at 60%
  beats running at 100% often enough that one number was the wrong answer. A druid's flight form
  counts. Classic Era shows ground speed alone, because nothing flies there, and Mists reads
  speed off your riding rank the way that game gives it.

### Mail that is about to expire

- **Family says at login whose mail is running out** — one character to a line, most urgent
  first, with how long is left and whose character it is. The character you are playing is named
  too: the game puts an envelope on your minimap and never says when what is in it disappears.
  Three days' warning by default, anything from one to thirty, and switchable off.

### Sharing with a friend or a guild

- **Three more things can be shared:** time played, rested experience, guild and hearthstone;
  currencies; and Chronoboons with what is banked in them. Each is its own tick, so you can share
  where your alts are bound without saying how long you have played. Nothing you already share
  widens on its own.

- **Crafting cooldowns travel with professions**, because a recipe list that cannot say *not for
  three days* answers half the question it was shared to answer.

- **Give a linked family a name of your own** instead of *Smith-PyrewoodVillage*. It stays on
  your screens and is never sent to them.

- **Only what has changed is sent.** An exchange used to carry every shared character's whole
  record every time either of you logged in. *Update now* still sends everything, because that is
  the button you press when something looks wrong.

- **A linked family's characters turn up where they were missing** — in *Can make it* on a
  recipe tooltip, in the profession search, in the bag search with the family they belong to
  beside them, and in the summary's crafting and currency columns.

### Reads in your language

- **Quest names, quest headings and zones read in your own words**, whoever recorded them and
  whatever language they play in — including on records written before this update.

- **Where a character logged out** now says the zone and subzone in your language, on
  Miscellaneous and shared with a linked family.

- **The filter buttons say *all* in your language**, which they did not on any non-English
  client.

### Faster

- **Logging in is quick again however many characters you have.** Two or three hundred characters
  used to cost several minutes at every login; Family now recognises a record that has not
  changed and moves straight past it.

- **Item and recipe names are remembered between sessions**, in each language separately, instead
  of being learnt from scratch every time you log in. A new game build throws the list away and
  learns it once more, so a name Blizzard changes is not remembered wrong.

- **Family says when it is still learning what your recipes are called**, on the first login
  after installing or after a patch, instead of leaving you with an hourglass and no explanation.

### Fixed

- **Two characters of the same name on different realms are two characters again.** Both can be
  logged in at once from two accounts, and an update no longer reports a whole family offline
  because of it.

- **Some of a letter's attachments were not recorded.** A letter with gaps in it had part of its
  contents silently left out; every slot is read now.

- **A shared character's mail expiry and auction age never arrived**, so a link that granted Mail
  sent the letters but never when they expire.

- **A quest's tooltip shows that character's progress**, with the objectives they have finished
  in green, rather than describing the quest as it stands for whoever you are playing.

- **The login notice about cooldowns puts one character on each line** and names what each is
  waiting on, instead of running every name together in a paragraph. It counts cooldowns rather
  than recipes — three transmutes are one timer — and it tells you about the character you are
  playing, which is the one you can do something about.

- **A cooldown is named after its profession**, so an alchemist's timer reads **Alchemy** rather
  than *Transmute: Fire to Earth*, which is one recipe on a timer that covers all of them.

- **A profession somebody unlearns is dropped**, and stops being an answer to *who can make
  this* for you, your guild and any linked family.

- **A linked family's quests, letters and crafters are readable** — three panels were answering
  *nothing recorded* however much had been shared.

- **Realm names, guild names and long zone names stop being cut off or running over** their
  columns, on the Wide Family panel and on Miscellaneous.

- **Typing in a filter box no longer keeps the keyboard**, so the arrow keys turn your character
  again after you click away.

- **A linked family being offline no longer fills your chat** with the game's *no player named X*
  lines.

- **Names are coloured by class** wherever the whole family is listed, and carry their realm when
  it is not the one you are standing on.
