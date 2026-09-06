## 2.0.0 — 2026-09-06

### Added

- **The Crafting page is a list of cooldowns now, not a grid of them.** Each timer gets a line of
  its own with everybody who has it underneath - readiest first - and how many of them can do it
  right now beside the name. It used to be one column per cooldown and one row per character,
  which meant the page could only ever show four kinds of cooldown however many your family had,
  and quietly dropped the rest. There is no limit now.

- **A quest's own progress no longer has your name over it on your own page.** Hovering a quest on
  the character you are playing showed the game's *You are on this quest*, then your name, then
  your objectives - a heading that told you nothing you did not already know. It is still there on
  every other character's page, where it says whose the numbers underneath actually are.

- **The login notice tells you about your own character too.** It listed every alt with a crafting
  cooldown ready except the one you had just logged in on - which is the one you can do something
  about without logging out again.

- **A shared crafting timer is named after its profession, not after one recipe on it.** All of
  an alchemist's transmutes sit on one cooldown, so a column headed *Transmute: Fire to Earth* was
  telling you about a timer that covers every transmute they know - and Family only headed it that
  way when it happened to have recorded a single one of them. It now asks the game which
  professions share a timer instead of working it out from what it has watched, so the column
  reads **Alchemy** from the first transmute onward. Enchanting's Void Sphere and Prismatic Sphere
  are one timer too, on the clients that have them, and now say so; Jewelcrafting's Brilliant
  Glass keeps its own name, because its cooldown really is its own.

- **A linked family's cooldowns and currencies get their own columns.** On the summary's Crafting
  and Currencies sets, a character shared with you was listed but had nothing on their row unless
  somebody in your own family happened to hold the same thing - so a friend's alchemist showed up
  with her transmute ready and an empty line. The columns are now built from everybody the grid
  draws.

- **A linked family's characters appear in "Can make it" again.** Hovering a recipe listed who in
  your own family and your guild could make it, and quietly left out the characters a linked
  family shares with you - even though the professions panel one click away had them, and even
  though the same tooltip's possessions list has always shown them. They are back, named with the
  family they belong to, on a recipe's tooltip and on a pattern's.

- **The whole-family possessions search reads as a list again.** Searching for an item used to
  draw its name once for every character who had some, with that character's count against the
  name - so five holders of a bronze bar gave you five lines all beginning *Bronze Bar 209*, and
  the number looked like part of what the thing is called. The item is now written once with its
  holders under it, most first, and how many they have leads the right-hand column in front of
  where they are: **209 (62 bags, 147 bank)**, the same sentence the item's own tooltip writes.
  Sorting by character does the same the other way round - the character once, with what they are
  carrying beside them. More than three holders fold behind a line you can click, as on the
  reputations list - and, as there, the item's own first line opens and closes them too.

- **Logging in is quick again however many characters you have.** Family used to read every
  character's record once a second after login to learn what their recipes are called - four
  seconds for a small family, and several minutes for somebody with two or three hundred
  characters, at every login, almost all of it spent discovering there was nothing new to learn.
  It now recognises a character whose record has not changed since it last read it and moves
  straight past, twenty at a time. A character who has been played since is read as before, and
  so is one whose names the game would not give.

- **Ask the professions panel about one weapon skill.** Switch it to Weapon Skills and the filter
  beside it now offers weapons instead of professions - pick Swords and the panel comes down to
  whoever has them, headed by the weapon's name, and clicking that heading puts the family in
  order of who is furthest behind on it. It asked about professions over a table of weapon skills
  before, which narrowed one list by the other.

- **A linked family's recipes are learnt at login too**, instead of being paid for the first time
  you open their profession. Sharing with a family who play in another language is exactly where
  the names have to be looked up, and it was the one case the login pass did not cover.

- **The first login is quick again if you play in one language.** Family was asking the game what
  every recorded recipe is called, even for the lists it had read on your own client in your own
  language - where it already has the name and needs nothing. It now asks only about the lists
  read in some other language. `/family recipes` says which those are, per profession.

- **Family says when it is still learning what your recipes are called.** On the first login after
  installing or after a game patch it reads every recorded recipe's name once, and until that
  finishes the Professions window can pause when you open it. It now says so - on that window
  while it lasts, and once in the chat frame for a large family - instead of leaving you with an
  hourglass and no explanation. It says nothing at all from the second login on, because by then
  there is nothing to read.

- **Family remembers what things are called between sessions.** Item names were asked of the client
  from scratch at every login - the client's own cache does not survive a relog - so the first
  minute of every session was spent learning the same few thousand names again. They are written
  down now, in each language separately, and a client running a new game build throws its own
  language's list away and learns it once more, so a name Blizzard changes is not remembered wrong.

- **A specialised character shows their branch's own picture.** An Axesmith's blacksmithing cell
  draws the axe rather than the anvil every other smith in the family is showing, a Goblin
  Engineer draws the goblin's head, a Mooncloth tailor the moon. Where a smith has gone deeper -
  Master Axesmith under Weaponsmith - the deeper one is what shows. A character who took no branch
  is unchanged.

- **A character's profession branches are named at last.** Hover a member on the Professions set
  and each trade lists the specialisations that character took under it - Weaponsmith, Dragonscale
  Leatherworking, Goblin Engineer - indented beneath the profession they belong to. The fact was in
  the record all along, because a branch is a spell and Family has stored the spellbook since the
  beginning; nothing had ever named it. Alchemy's Transmutation and Elixir masteries are included,
  which the old data could not see because they lock no recipe behind them.

- **Poisons and lockpicking have their own pictures**, like every other skill on that set - and
  poisons is now recorded by identity rather than by name, so a rogue read on one client and looked
  at on another is the same rogue.

- **Lockpicking sits with a rogue's other skills.** It was on the abilities page; it is now on the
  summary's Professions set, beside cooking and first aid, where the rest of what a character has
  already is.

- **Every profession a character has now fits on one line.** The Professions set was three wide
  columns holding an icon and a number, with the primaries on one line and everything else on
  another; it is seven narrow ones, the primaries first and the secondary skills beside them.

- **Weapon skills can be seen at last**, on a button beside the Professions filter that switches the
  panel between the two lists. They were recorded and shown nowhere. The panel opens on the
  professions and goes back to them when you leave it; the search box finds a weapon either way.

- **Riding is off the Professions page.** It was in the filter and in the rows, three cells of horse
  in the middle of everybody's trades. What is worth knowing about riding is how fast a character
  gets about, and the Overview says that already.

- **The Professions overview is drawn as pictures.** Each trade shows its own icon and its rank
  instead of its name and its rank, so a character's whole set of skills fits where two used to and
  the page can be taken in at a glance. Hover a row to read the names, under the game's own three
  headings - professions, secondary skills, weapon skills - with every rank beside it. The search
  box still finds a profession by typing its name.

- **CTRL now swaps a recipe's tooltip on Classic Era too.** Holding CTRL over a recipe has always
  shown what it costs to make instead of what it makes - but on Era the records had no way to name
  the recipe behind an item, so nothing happened and nothing said why. It works now on every
  profession, cooking and first aid included, and the grey line at the bottom of the tooltip tells
  you which rows offer it.

- **Quest tooltips in the whole-family view now say how that character is doing.** Hovering a
  quest there showed only the quest's own text; it now lists that character's objectives under it,
  the way the single-character page already did.

- **A druid's flight form counts as flying.** It is a spell rather than a mount, so it was not in
  the mount journal and a druid with no flying mount was being told they could not fly.

- **The Mount column is right on Mists of Pandaria too.** There the game gives the speed to your
  riding skill rather than to the mount, so buying Master Riding makes every mount you already own
  faster - and Family now reads it that way, from your riding rank and what your mount journal lets
  that character ride.

- **On Classic Era the Mount column stops promising flight.** Nothing flies in that game, so the
  dash that means *no flying mount* was saying nothing at all; there it now shows the ground speed
  by itself.

- **The Mount column says whether a character can fly.** Two figures, always: what they do on the
  ground and what they do in the air - *100%/60%* for somebody with a gryphon, *100%/-* for somebody
  without one. Flying at 60% beats running at 100% often enough that one number was the wrong
  answer.

- **A Mount column on the Overview.** How fast each character can get about - 60%, 100%, or faster
  - worked out from the mount they own rather than from the riding skill, so a paladin or a warlock
  on a class mount counts, and so does a character carrying one they bought. It is shared with a
  linked family alongside the rest of what a character is.

- **Mists characters keep their riding skill.** On that game Family was reading one list where
  there are two, so anybody with a profession lost their riding skill and every weapon skill
  without a word. Weapon skills stay absent there on purpose - that game took them out, and the
  numbers the client still holds mean nothing.

- **Weapon skills are recorded.** Swords, daggers, unarmed and the rest, at whatever rank each
  character has them. They are kept apart from professions, the way the game's own windows keep
  them apart, so the professions list is still a list of professions.

- **Riding counts as a profession.** It sits on your skill sheet beside cooking and fishing and
  Family did not know it existed; it now appears with the others, at whatever rank you have. On
  Classic Era the game names it after your mount - *Ram Riding*, *Raptor Riding* - and that is
  what you will see.

- **The filter buttons say "all" in your own language.** They read *all* on every non-English
  client, in the middle of a bar that was otherwise translated.

- **Quest headings that are not places now read in your language too.** A warlock's quests were
  filed under *Démoniste* on an English screen, and the cooking and blacksmithing headings the
  same way. They read as your own game names them now, on records written before this as well.

- **Quest names you can read.** Somebody else's quest list now reads in your own language, whoever
  recorded it - Family asks your game what each quest is called, the same way it already knows
  what to put in the tooltip, and remembers the answers so it only ever asks once.

- **Where a character logged out now reads properly for city zones.** Some places - Ironforge
  among them - were showing in the language of whoever logged out there rather than yours. They
  now read in your own words, and a character who logs out somewhere keeps the exact wording their
  own game used.

- **Miscellaneous says where each character logged out.** Zone on one line and subzone under it,
  in your own language rather than in whichever one that character was played in - and shared
  with a linked family alongside the hearthstone. Rows on that page are taller to hold it, and
  the other columns gave up the width. A character has no answer here until they have been
  played once since this update.

- **The guild panel can show only the guildmates who run Family.** A third button beside
  *Online only*. It starts off, because in most guilds that list is very short and a panel that
  opened on two rows would look broken rather than honest - and your own characters are always
  on it.

- **The summary's professions can be put in order of one profession's skill.** Choose a
  profession in the filter row and the column takes its name; clicking it then sorts the family
  by their rank in that profession rather than alphabetically by whatever they happen to hold.

- **The crafting columns can be narrowed to one cooldown.** The filter row on that set now
  offers the cooldowns the family is actually waiting on - *Alchemy*, *Mooncloth*, *Salt
  Shaker* - and choosing one leaves the members waiting on it and takes the other columns off
  the table. A family with more cooldowns than fit across a row used to be told how many were
  left out and given no way to see them; now they are one choice away.

- **The whole family's reputations list a faction and the characters who have met it.** It used
  to name only whoever had got furthest with each one. Now every character who has a standing
  with a faction is under it, furthest first, each with their own standing and score - so *who
  can buy that pattern* is a list of names to log in on rather than one name and a count. Three
  are shown at a time; where there are more, the line under them says how many and clicking the
  faction opens the rest.

- **The professions search across the family can be put in an order of your own.** By name, by
  profession, or by how many of the family can make each recipe. The sort bar stays where it
  always was and offers these three instead of the three it offers for one character - a
  recipe's colour and the skill it needed are what one character sees, and across forty there
  is no single answer.

- **The Character panel's filter box no longer runs under the Whole family button.** Across the
  family the row of filters stands where the member picker does and is wider than it, so a box
  of a fixed width overlapped the switch. It takes the room that is actually left now.

- **Quests are recorded with their identifier, so the game can describe them.** They never were:
  Family asked the client for one in a way the client does not accept, so every quest it has
  ever stored has been anonymous - which is why a quest row could only ever show Family's own
  summary. Newly read quest logs carry it, and the rows show the game's own tooltip.

- **Quest rows show the game's own description of the quest.** They always meant to, and asked
  the client for it in a form it ignores - so every quest row in Family has been showing its own
  short summary instead. The summary is still there for the quests the game will not describe.

- **TAB moves between the filter boxes.** On the summary, possessions, professions and the
  character panel, TAB takes the cursor to the next box on the filter row and Shift-TAB to the
  previous one, round rather than stopping at the end. Boxes that are not on the screen are
  stepped over.

- **Everybody's quests at once.** The Quests section now has a *Whole family* switch like gear
  and reputations. It lists quests rather than characters: one line per quest, and under it
  whoever has it, furthest along first, each with their own progress. Three at a time, with the
  rest a click away. So *who else is on this* is one look instead of forty.

- **A recipe row reads both ways.** Family's recipe rows show what the recipe makes; hold CTRL
  with the pointer on one and it shows the recipe itself, without moving the mouse. The row
  says the key is there. Where a recipe makes no item - every enchant - nothing is offered,
  because a swap to the same tooltip is not a swap.

- **The Character panel has a level range like everywhere else.** Switch it to the whole family
  and the row of filters is realm, class and a range of levels - the same row the summary and
  the professions and possessions searches carry. It offers the realms and classes your linked
  families are on as well as your own, because this panel draws their characters beside yours.

- **The summary's professions can be narrowed to one profession.** *Who are the blacksmiths?* -
  open Professions on the summary and there is a picker beside the class and level filters
  offering the professions your family actually has. It works with the others rather than
  instead of them, so *which of my level 60s are blacksmiths* is one row of controls.

- **The possessions search can be put in an order of your own.** Searching the whole family
  there is now a *Sort by* row: by item, by character, or by how many. By character puts
  everything one alt is carrying together, which is the question the list could not answer
  before. A guild bank sorts among the names by its own.

- **The professions and possessions searches can be narrowed to some of your characters.**
  Switch either panel to the whole family and there is a row of filters under the search box -
  realm, class, and a range of levels. A recipe nobody left can make, or an item nobody left
  holds, drops out of the results entirely rather than sitting there naming no one.

- **The summary can be put in an order of your own.** Click a column heading to read the table
  by it - money, rested experience, last seen, free bags, mail, when it expires, auctions and
  what they are worth, banked world buffs, currencies, who can craft something soonest, guild,
  hearthstone, race, class - and click it again to turn it round. A third click gives the panel
  its own order back. Each set of columns remembers its own, and remembers it between sessions.
  A character something has never been read for goes last whichever way the column points,
  rather than sorting as a nought and looking like the poorest character in the family.

- **A rogue's lockpicking is recorded.** It shows on Abilities & Talents, under Spellbook, with
  its rank - it is an ability rather than a profession, so it is not among your professions and
  is not counted as one. Classic Era and Burning Crusade only: the skill does not exist on
  Mists.

- **A key can open Family.** It is in the game's own Key Bindings window, under *Family*, with
  nothing bound to begin with - choose the key you want. Pressing it again closes the window.

- **The whole family's reputations on one screen.** The Character panel's Reputations section
  has the same *Whole family* switch its gear already had. It lists factions rather than
  characters: for each one, how far anybody has got, which character got there, and how many of
  them have met that faction at all - so *is anybody exalted with the Thorium Brotherhood* is
  one look instead of forty. The realm, class and name filters work on it.

- **A linked family can share three more kinds of thing, and crafting cooldowns now travel
  with professions.** Time played, rested experience, guild and hearthstone; currencies; and
  Chronoboons with what is banked in them - each its own tick on the Wide Family grid, so you
  can share where your alts are bound without saying how long you have played. Every one of
  these was a column that stayed empty for a shared character however much had been granted.

  Crafting cooldowns go with the profession they belong to rather than needing a tick of their
  own, so a family who already shares Professions with you will start showing them at the next
  update: a recipe list that cannot say *not for three days* only answers half the question it
  was shared to answer.

  Nothing you have already shared widens on its own. The three new categories start unticked,
  as every category does.

- **You can give a linked family a name of your own.** A link is made with a character, so
  until now every panel and tooltip labelled their characters with something like
  *Smith-PyrewoodVillage*. Open the link on the Wide Family panel and there is a box to call
  them whatever you like; empty it and the real name comes back. It is only on your screens -
  it is never sent to them - and it does not change who Family whispers, which the panel says
  and shows in grey beside it.

- **Family says at login whose mail is running out.** A short list in the chat frame, one
  character to a line, most urgent first: the name and realm, how long is left, and - when the
  character belongs to a family you are linked to - whose they are. Something already lost is
  said to be already lost rather than dressed up as expiring now. The character you are playing
  is named too: the game puts an envelope on your minimap and never once says when what is in
  it disappears. Everybody is listed, however many there are - if that is more than you want to
  read, the warning period is yours to shorten.

  It is on to begin with and switches off in the options panel, where you also choose how much
  warning you want. Three days by default, anything from one to thirty.

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

- **Realm names on the Wide Family panel are no longer cut short.** `Thunderstrike...` and
  `Spineshatter ...` had been squeezed into the width a member's name gets, and a member's name is
  narrow because it has tick boxes beside it - a realm heading has nothing beside it at all. Both
  grids are fixed, what you share and what they share.

- **Guild share stops offering things no guildmate could ask you for.** Weapon skills, riding,
  lockpicking, defense and poisons had all appeared as tick boxes on the Guild page - a level 5
  character was offering to share *Daggers 1/25*. Guild share answers one question, who can make
  this, so only professions with something to make are offered now. Anything already ticked for one
  of them stops being sent.

- **A long guild name no longer runs over the edge of its column.** *Loch Modan Yachting Club* was
  being drawn past the end of the Guild column on Miscellaneous; it is shortened now, with the whole
  name on the row's tooltip beside where that character is - the same as the Where and Hearthstone
  columns next to it.

- **A linked family is sent what has changed, not everything again.** Every exchange used to carry
  each shared character's whole record - bags, equipment, professions, mail, the lot - and that
  happens every time either of you logs in, and again on every sharing change. Now only the
  characters whose records have actually moved are sent, and a sharing change no longer asks them
  to send their entire side back in reply. **Update now** still sends everything, because that is
  the button you press when something looks wrong.

- **Sharing decisions wait three seconds for you to finish before they are sent.** Every tick of a
  box used to package and send everything you share with that family, immediately - so working down
  a column of categories sent the whole lot once per column, and the other side watched the marks
  arrive in bursts over a minute or two while all but the last transfer was already out of date.
  Family now waits until you stop clicking. Nothing waits on a button: taking something back still
  reaches them without anyone pressing Update.

- **Clicking `Sibling` ticks or clears that whole column**, the way clicking a category's name
  already does on the grid above it. It was the one column on Wide Family that did not offer the
  gesture, and it is the one that is yours to decide rather than theirs. Nothing is sent: which of
  their members you keep in your own summary has never left your machine.

- **A linked family's block on the summary says which realm it is on.** It carried the family's
  name and nothing else, at the same indent as a realm heading - so a family with characters on two
  realms produced two blocks that read as two realms of the same name, and neither said which realm
  it was. The block now sits a level in, where the Alliance and Horde headings are, with the realm
  in grey beside the family's name. Reported from play.

- **The Overview row says what a character is allowed to ride, not only what they can.** Hover a
  member and the tooltip gives their speed and the riding skills they hold. It matters when the two
  disagree: somebody who earned tiger riding and then sold or destroyed the tiger had a blank in the
  Mount column and no way to tell that from never having learnt to ride at all. A character whose
  bags have never been read still shows a dash there, because that is a different blank again.

- **Mists no longer offers a Weapon Skills page it has nothing to put on.** That version of the
  game has no weapon skills, so the button that switched to them is gone there and the caption
  under the table stops mentioning it. Era and Burning Crusade are unchanged.

- **Weapon skills are recorded again on Era and Burning Crusade.** They had stopped: the check that
  decides whether this version of the game still has weapon skills was asking the wrong question,
  and answered "no" on the two versions that do. A character's weapons come back the next time you
  log in on them. Mists is unchanged - it has no weapon skills, and the numbers the game still
  reports there govern nothing.

- **Choosing Lockpicking on the professions filter no longer empties the panel.** It was offered in
  the list and matched nobody, so picking it left every rogue hidden and a note underneath saying
  how many. Ordering the panel by it did nothing for the same reason; both work now.

- **A profession somebody unlearns is dropped from the record, recipes and all.** It stopped being
  shown a version ago; now it stops being stored and stops being sent to a linked family. A
  profession that has never been on the skill sheet at all - a death knight's runeforging - is kept,
  and nothing is dropped on a login where the skill sheet could not be read.

- **A profession somebody unlearns stops being an answer to "who can make this".** Family kept the
  recipe list after the skill was gone, so an item's tooltip and the family recipe search went on
  naming a character who could no longer make it - and with no rank beside them, which is how a
  character Family has never read appears. Guildmates and linked families stop seeing it too.

- **A character's location no longer pushes their row out of line.** A long subzone under a long
  zone wrapped onto a third line on Miscellaneous and left that member half a row out of step with
  everybody else. Both halves are cut to fit now, and **hovering the row gives the whole of where
  they logged out and where their hearthstone is** - which the Hearthstone column has always been
  too narrow to say in full.

- **The Professions page stops calling riding a profession nobody opened.** *Ram Riding* was in
  the grey line under the profession buttons, listed among the windows Family has never seen -
  and there is no such window. It is off that page entirely now, as it already is on the summary.

- **The Professions page stops blaming a window that does not exist.** Herbalism, skinning,
  fishing and a rogue's lockpicking were listed among the windows Family has never opened, and
  there is nothing to open: they make nothing. The grey line says that about them now, and says
  it about lockpicking at all, which it never used to mention. Mining is not one of them - its
  window is Smelting's.

- **A profession recorded before Family knew its identity now draws its picture too.** Two rogues
  side by side showed one poison bottle and one clipped word: the second had not been scanned
  since poisons gained an identity, and the panel was looking the picture up under whatever key
  the record happened to carry. Nothing needs re-scanning.

- **The Professions switch no longer runs off the edge of the window.** It holds the right-hand
  end of the filter row now, where nothing before it can push it, and the search box gave up
  thirty pixels to make room. Family says so in the chat frame if a language ever runs that row
  out of pixels again.

- **A shared character's quests are named as your own game names them.** A linked family playing
  in another language sent their quest titles and zone headings in that language, so their quest
  page read in French on an English client - while the tooltip on the same row read in English.
  Both now use your own words where your game will give them.

- **A shared character's quests are filed under the zone as you call it.** With a linked family
  playing in another language, one zone appeared twice on the whole-family quest page - once
  under its English name and once under theirs - with its quests split between them. It is one
  heading now, in your own language. A character's log picks this up the next time they are
  played.

- **CTRL swaps a recipe's tooltip even while you are typing in the search box.** Holding CTRL
  over a recipe shows the recipe instead of what it makes - and it stopped working the moment
  anything was typed into a search box, which on the whole-family pages is always.

- **Switching *Whole family* on or off clears that page's filters.** A realm, class or level
  range typed for one character stayed on when the page changed to the whole family, and a
  narrowing that meant one thing over one character means another over forty - so the page
  looked as though it had lost people rather than as though a filter was still on.

- **Typing in a filter box no longer keeps the keyboard.** After typing into one of Family's
  boxes, clicking anywhere else - including on the game world - left the keyboard in the box,
  so the arrow keys typed into it instead of turning your character and only Escape or closing
  the window got it back. A click outside the box now gives it back.

- **The number beside a category heading is no longer under *Standing*.** On the reputations
  and quests pages a heading like *Alliance* showed how many factions were under it, in the
  column that everywhere else says how far along you are - so it read as a standing. It sits
  beside the heading now, in brackets.

- **A linked family's characters appear in the professions search.** Turning *Whole family* on
  and searching for a recipe listed only your own characters, however much a linked family had
  shared with you - and their skills were on the summary at the same time. They are named with
  their rank now, and marked as theirs, because they are somebody to ask rather than somebody
  to log in on.

- **The character picker calls a linked family by the name you gave it.** It headed their
  characters with the character the link was made through - *shared by Grella-Thunderstrike* -
  while every other screen used the alias.

- **Character names are coloured by class where the whole family is listed.** The reputations
  and quests pages and the professions search used to draw every name in one gold, which for a
  family of twenty is a list you have to read rather than glance at.

- **A name's realm no longer disappears when you hover it.** On the whole-family reputations and
  quests pages the row said *Eccebombo (@Soulseeker)* and the tooltip beside it said only
  *Eccebombo*, so the one thing telling two characters of one name apart went missing exactly
  when you asked for more detail.

- **A quest's tooltip now shows that character's progress through it.** Hovering a quest said
  *You are on this quest* and listed every requirement unmarked, whoever the row belonged to -
  the game describes a quest as it stands for the character you are playing, and on this panel
  that is almost never the one you are pointing at. Each objective is now listed underneath,
  with the ones that character has finished in green and their name above them. Quest logs read
  before this update carry no objectives until that character is played again.

- **The login notice about crafting cooldowns puts one character on each line, and says what
  is ready.** It used to run every name together on one line with a count after each - which
  for anybody with a dozen crafters was a paragraph across the chat frame, and never said what
  any of them was waiting on. Each line now names the cooldowns themselves, carries the
  character's realm where they are not on the one you are playing, and marks a character on
  the other side. Salt shakers and the other crafting items are announced now too, beside the
  transmutes and the mooncloth - the Crafting table has always shown them and the line never
  did. Their names are asked of the game a few seconds before the line is written, so an item
  that belongs to a character you are not playing is named rather than numbered.

- **The login notice counted recipes instead of cooldowns.** An alchemist who has learned three
  transmutes has one cooldown, not three - the game puts every transmute on the same timer - and
  the line at login was announcing *(3)* where there was one thing to go and do. It now counts
  the same way the Crafting table does.

- **A linked family's quests, letters and crafters are actually readable.** Opening a shared
  character's Quests said *Nothing recorded for this member* however much they had shared;
  unfolding their letters on the summary drew none; and on an item's tooltip they were left out
  of who can make one. Three panels were asking Family's own storage for records that belong to
  somebody else's family, and getting the honest answer to the wrong question.

- **Something you unfolded folds itself away again.** A faction opened to see all its
  characters, or a recipe opened to see everyone who can make it, used to stay open - so
  closing the window and coming back found the page still unfolded, with nothing on screen to
  say why. It closes when you put the window away, and when you click the tab, section or
  profession you are already looking at, which is how you ask for the page back. The summary's
  letters and banked buffs behave the same way now.

- **The possessions search says whose character it is.** Searching across the whole family, a
  character belonging to a family you have linked was listed exactly like one of your own - so
  a count beside a name read as *I can go and get that* when you cannot. They now carry their
  family, the way the item tooltip has always shown it.

- **A guild bank stops carrying a realm you are standing on.** *Loch Modan Yachting Club* on
  your own realm was drawn with its realm on the end and cut to fit, losing the end of the name
  as well. A guild on another realm still says which, exactly as a character does.

- **A sort caption that runs onto two lines no longer sits on the line below it.** The row of
  sort buttons grows to hold its caption instead of keeping a fixed height. English fits on one
  line and never showed this; the longer translations of the same sentences do not.

- **The professions panel no longer explains a sort order it is not using.** Searching the
  whole family put the sort buttons away and left their caption behind, so *Hardest first* sat
  over a list of recipes in alphabetical order. The caption goes with its buttons.

- **The filters on the professions and possessions searches are actually on the screen.** They
  were being switched on and drawn through the line of text under the search box, which runs
  the full width of the panel, so neither was visible and the panel looked as though the
  filters had never been built. They now sit on a line of their own and the results start
  below them.

- **Two characters of the same name on different realms are two characters again.** A name
  belongs to a realm rather than to a group of them, so a linked family - or yours together
  with a linked one - can hold two Rolandos, and both of them can be logged in at once from
  two accounts. Family had been treating them as one character: the game refusing to write to
  the one who was offline took the other off the list of who to try for a minute and threw
  away everything waiting to go to them, so an update could report that none of a family was
  online while somebody was sitting in front of one of those characters. Where the game's
  refusal does not say which of the two it means, and Family had just written to both, Family
  now assumes nothing about either rather than assuming it about both.

- **Two messages that were missing a word.** *Update now* on a linked family, and the guild's
  own update button, both answered a failure with "Could not:" and then the reason - a sentence
  with its verb missing. They say what could not be done now.

- **A linked family being offline no longer fills your chat.** Finding somebody online in a
  linked family of six means writing to each of them in turn, and the game answers every failed
  one with *No player named X is currently playing*. Those are the game's lines rather than
  Family's, which is why switching Family's own reporting off never quietened them. They are
  taken off the screen now - only the ones answering Family's own writing, only for a few
  seconds after it, and never a reply to a whisper you sent yourself.

- **The key binding now has a section of its own, and stops complaining.** Family's binding sat
  in *Other* under a row reading `HEADER_FAMILY`, because the file declared its section the way
  an older client expected. It is under **Family** now. The same file was also named in the
  table of contents as well as being found by the game, which made Burning Crusade print three
  warnings at every login; those are gone too.

- **Some of a letter's attachments were not recorded.** A mailbox does not keep a letter's
  attachments in its first slots, or in order - taking two out of a letter and leaving the rest
  puts gaps in it - and Family read only as many slots as the letter said it had things in. So
  a letter of ten with gaps had some of them read and the rest silently left out. Every slot is
  read now, and what the letter says it holds is kept beside what was found.

- **A character could be listed twice on one recipe.** Where a stored recipe list held the
  same recipe on two rows, the person who knew it was drawn twice on the same line - with
  their realm on both, because two identical names are exactly what makes Family add it. They
  are now listed once, keeping whichever of the two copies knows about a cooldown that is
  still running.

- **A shared character's mail expiry and auction age never arrived.** Wide Family named two of
  the figures it shares by the wrong name - one letter out in each - so a link that granted Mail
  sent the letters and the count but never *when they expire*, and a link that granted Auctions
  never sent how old the snapshot was. Both sides looked like they were working. They now
  arrive; a character you already share updates the next time they are seen.

### Changed

- **Names say which realm they are on, when it is not the realm you are playing on.** Item
  tooltips and search results used to add the realm only where two of the listed names were
  identical, which told you nothing when a single character called Tossica holds the thing and
  you still have to work out where to log in. Character names are unique per realm, not per
  realm group, so alts on two realms of one group can mail each other and still be two
  different people. Nothing is added for the characters on the realm you are standing on, and
  lists that are already grouped by realm say it in their headings as before.

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
