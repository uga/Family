## 3.0.0 — 2026-09-13

**Pets, and a Wide Family that keeps up.** Hunters and warlocks get a Pets page listing every
stabled pet and summoned demon with what each one can do, down to what its abilities cost in
training points. Sharing with another family is faster, no longer freezes the game, and now
picks itself up where it left off.

### No more *script ran too long* on the first search of a session

- **Searching recipes or pointing at a recipe right after logging in no longer stops the game.**
  Family now keeps your characters' data ready to read instead of unpacking all of it the first
  time you ask about the whole family. The first login after updating converts what is saved, a
  little at a time, and nothing is sent again to families you share with.

- **The whole-family recipe search waits for you to stop typing**, and puts its results in order
  without looking every name up again - lighter on every key, most of all on Classic Era.

- **Pointing at a wand, rod or oil no longer looks up every recipe name in the family**, and
  opening one character's professions reads that character alone instead of everybody.

- **Recipe search and *who can make it* answer straight away**, from a list Family keeps ready
  after you log in instead of reading every character again each time.

### Fixed on Mists of Pandaria

- **What a character has up for sale was always empty.** Family was asking that version of the game
  a question it stopped answering, and getting silence back — which looks exactly like having no
  auctions. Your listings, and what they are worth, are read again.

### What it is all worth

- **A Worth column on the summary's Overview**, beside Money — what everything that character is
  holding comes to, in gold. The row's tooltip gives the exact figure and how much of it came from
  auction prices and how much from what a vendor pays.

- **It adds up per realm and per faction**, like the money beside it. A character nothing could be
  priced for is blank rather than nought: that is Family not knowing, not them owning nothing.

- **Clicking a character on the Bags set opens their possessions**, the way clicking a profession
  already opened that profession.

- **The Mount column moved to Miscellaneous** to make room, and **Class moved into the row's
  tooltip** to make room for it there. A character's class is still on every row, in the colour of
  their name. Race now leads the Miscellaneous columns, and on Bags each *seen* column sits beside
  the numbers it dates instead of both of them queueing at the end.

- **A character's Possessions page says what everything they hold comes to**, under the line about
  how recently each part of it was seen. Bags, bank, mail and auctions — not the guild bank, which
  is the guild's, and not the keyring.

- **Priced at the auction house where Family has seen one, and at what a vendor pays where it has
  not.** The game knows what a vendor pays for nearly everything, which is what makes the figure
  cover a whole bank alt rather than the few dozen things you happened to search for.

- **It never gives a total on its own** — how much came from auction prices, how much from vendor
  prices, and how many things it had no price for at all.

- **An item's tooltip says which of your *other* characters' copies are soulbound**, in the game's
  own word — something no other addon can tell you, because their copy is not on this machine. For
  the character you are playing the game already says it, and Family does not repeat it.

- **Your own gear and bags are described by the slot they are in**, so a shield you wore once
  reads *Soulbound* on Family's page exactly as it does in your bag, instead of *binds when
  equipped*.

- **Soulbound things are valued at what a vendor pays, never at the auction house.** What is on
  sale there is the unbound version of an item: a sword you have worn cannot be listed at any
  price. Two of the same sword on one character — one worn, one not — are now worth what they are
  really worth, which is not the same figure twice.

### Extras

- **"Can make" counts what the character has in their bags and bank**, as of the last time they
  logged in, instead of what their profession window said the last time it was opened.

- **Hover a letter under a character to read it in full**: the whole subject, who sent it, when it
  expires and the money in it.

- **Wands, rods and oils an enchanter makes are shown as the thing itself** on the Professions
  panel, with who holds one and what it takes to make - and with their own picture on the row
  rather than enchanting's.

- **An enchant's tooltip says what it is made of**, with how many of each and what that costs,
  under who in the family can do it.

- **What a thing is made of now appears on far more items on Burning Crusade and Mists** — every
  recipe a trainer teaches was missing it.

- **Prices on item tooltips are written in full**, gold, silver and copper, so a column of them
  lines up.

- **CTRL on a recipe now does what it does everywhere else**: it adds up what the family holds of
  what the recipe makes and what that is worth. It used to swap to the recipe, which the pictures
  of its materials on each row have made unnecessary.

- **Every recipe row says what it is made of.** The materials, with how many of each, on the right
  of the recipe's own line — for every character, not only the one whose profession window is
  open. On the whole-family search, where the row already carries a recipe and everybody who can
  make it, click the recipe and the materials appear on a line underneath.

- **Opening a recipe on the whole-family search lists several crafters to a line**, in the same
  column the folded row uses, instead of one name per line. A dozen people who can make something
  was a dozen rows, which scrolled the recipe's own name off the top. Each line now holds as many
  names as will actually fit, so a borrowed family's character carrying their family name with
  them no longer costs a whole row.

- **The money that came out of the mailbox, in chat.** A line for each sum as it arrives, and,
  as soon as there is nothing left to take - or when you close the mailbox, if that comes first -
  what the visit came to - a moment after the last letter, so it
  lands below the game's own line for what was in it. The game
  already tells you about items; it says nothing about the gold in a mailbox full of auction
  sales. Works with the game's own Open All and with mail addons. Off until you switch it on.

- **Reading prices and reading the whole house are two separate switches.** Using an auction house
  fills Family in, and so does the full scan of an addon like Auctionator — Family listens and
  takes the prices for nothing. Family's own page-by-page read is the second switch, and it is for
  people who have no such addon: the game only lets one search out at a time, so it takes minutes.

- **What a craftable thing is made with, on its tooltip.** Every material and how many of it,
  under who can make it and above what it sells for — for anything a profession makes, whether or
  not any of your characters can make one. Where Family has prices it totals them, cheapest source
  first: a material it has no price for makes the recipe say *some prices are missing* rather than
  quietly totalling without it, and one that no money can buy adds nothing, with the total saying
  so. Off until you switch it on.

- **A material that is itself made follows its own recipe.** A Lionheart Champion needs a Lionheart
  Blade, which nobody sells and every crafter makes — so its cost is what the Blade's own materials
  come to, plus the rest. It follows a chain as deep as the game has: a Runed Eternium Rod is eight
  rods, and all eight are counted. Where somebody is selling a part, what they are asking wins over
  what making one would cost.

- **A new Extras panel, above Options**, for the jobs Family will do for you that are not what
  Family is for. Each one is off or on by itself, and a new one always arrives off.

- **Reading prices at the auction house is now one of them**, and it is on, because Family has
  always done it. Switch it off and Family values what your characters hold at what a vendor pays
  — which the game states for nearly everything — reads nothing at an auction house, and puts no
  tab on that window. Prices already recorded are kept, so switching it back on finds them.

- **Prices on a tooltip line up in a column again.** The age of an auction reading now leads the
  line in brackets — *(1h ago) 3s 92c* — instead of trailing it, so the sell price, the auction
  price and what your family's lot is worth all end at the same edge.

### Wide Family

- **Logging in no longer sends your whole family to everybody you share with.** A character goes
  again when something about them changed, not because you logged in; how long ago they were seen
  still updates on the other side. The first exchange after updating sends everyone once more.

- **Exchanges only send the characters that changed.** They were meant to from the start and were
  sending everybody every time. On a link of thirty characters that is most of every exchange.

- **Update now sends what changed, not your whole family again.** It asks for theirs and sends what
  is new, even with automatic exchange off, and when nothing has changed it says *nothing to send*
  and how many are unchanged. Sending everybody again is still there, as **`/family wide resend
  <family>`**, which tells you first how much it will send and how long it will take - about six
  minutes for two hundred characters.

- **`/family decodecost`** says what every character's record weighs, how many are still saved the
  old way, and which recipe lists are in another language, naming each character's lists that are.
  A measurement; it changes nothing.

- **`/family status` says how long your saved Family data took to read when you logged in**, and
  how many characters are still saved the old way. A measurement; it changes nothing.

- **`/family paycost`** says how many times this session wrote a character's record and which
  parts, and what marking each part of the current character's record takes on your client. A
  measurement for a change still being designed; it changes nothing.

- **`/family widetime` says which characters are waiting to go, and why.** Changed since they were
  sent - which is what playing one does - is counted apart from never confirmed as sent, and
  each group is named.

- **A shared character shows when it was last seen**, not when it was last sent. Every one of them
  used to look freshly updated after each exchange, whatever its real age.

- **The line under a linked family no longer loses its last words.** *Sending to them, 4 pieces
  left* was being cut to *send...* on narrower panels. Where the line will not fit, the hint about
  clicking the name gives way and the facts stay.

- **A linked family on a realm you cannot whisper is no longer reported as offline.** Whispers only
  reach your own realm and the realms connected to it; Family now says that none of their characters
  is on a realm this character can reach.

- **The Wide Family page no longer makes the game stutter while a large family is being sent.**
  With two hundred characters going out and the page open, it redrew every character and tick box
  once a second to move one count; now it moves the count and leaves the rest alone.

- **Their Update now no longer slows down what you are already sending them.** Pressed while a
  transfer to them was under way, it queued the rest of that transfer a second time. The request
  is now answered once, as soon as what was in flight has gone.

- **Ticking Exchange automatically back on does something at once.** It used to wait for the next
  login on either side; now it tells your linked families you are there, as a login does.

### Stack prices wherever a pile is in front of you

- **Hold CTRL over an auction and Family says what that stack is worth**, the same line it has
  always drawn over a stack in your bags. It follows the row you are pointing at, scrolled or
  not.

- **The same at a vendor and over a loot window**, so what a purchase hands you and what is
  lying on the floor are priced the way what is in your bags already was.

### A Family tab on the auction house

- **The auction window has a Family tab**, with the *Read it all* button on it and a line saying
  how far along a read is — pages done, prices taken, and roughly how long is left. Reading the
  chat frame while an auction house scrolls past was never going to work.

- **It also says when somebody else's scan is filling your prices.** Family reads whatever the
  auction window is showing, so another addon's whole-house scan fills the same store — 28,758
  rows in one go on a Classic Era house — and the tab now says so while it happens.

- **Family's own read is slower than that, and it is the server's throttle rather than anything
  Family decides.** A whole Classic Era house is 584 pages in five minutes: one minute waiting for
  answers, three minutes with the game refusing to let the next question out, and 27 seconds of
  Family's own pacing.

- **A price read at a goblin auction house counts for both sides of that realm.** It is one market
  shared by everybody there, so a character of the opposite faction on the same realm is valued
  from it too — and one on a different realm is not. Your own side's house still wins wherever it
  has a price, because that is where you would actually buy.

### Of the Bear and of the Whale are two different swords

- **Random-enchantment items are counted and priced one suffix at a time.** A Superior Sword *of
  the Bear* and one *of the Whale* share an item number and nothing else — different stats,
  wildly different prices — and Family used to add them up as one thing and put the cheaper one's
  price on both. Hovering the Bear one now says how many of *those* the family has, and what a
  Bear one is going for.

- **It is not a rare case.** A whole Burning Crusade auction house read end to end held 4,607
  items and 10,494 things once the suffix told them apart. More than half of what is on sale was
  being priced off a sibling.

- **Who can make one is still asked about the item.** The suffix is rolled at the forge, so one
  blacksmith's plans make every version — the crafters block on a tooltip is unchanged.

- **Enchants and gems are not variants.** Two of the same sword with different enchants are still
  two of one thing to count, and each still shows its own enchant when you point at it.

- **A search for a green now lists each version on its own line**, named and drawn as itself,
  instead of one line reading *<Random enchantment>* for all of them.

- **Prices already saved are unaffected.** Anything without a suffix keeps the price Family had
  for it. A suffixed thing has no price until the next time you have the auction house open, which
  is honest where the shared one was wrong.

### A family bigger than a tooltip

- **The minimap and broker tooltip no longer runs off the screen when many characters have a
  crafting cooldown ready.** It named every one of them on one line - 44 in a family of two hundred
  - and now says how many; the Cooldowns page lists who.

- **An item nearly all your characters carry no longer fills the screen.** With two hundred
  characters holding a Runecloth Bag, its tooltip listed every one of them. It now names the ten
  holding the most and counts the rest, with how many they hold between them so the total at the
  top still adds up. Guild banks the same.

- **A character's tooltip no longer says *May ride: Riding*.** From Burning Crusade on there is
  one riding skill for everything, so naming it said nothing the speed above it had not already
  said. On Classic Era, where each animal has its own skill, it still lists them.

- **Nothing the game will not pay a copper for is announced as being worth something.** An item
  with no sell price used to offer the CTRL line and then answer *Worth 0c*.

- **The CTRL hint on a stack says both things it will show.** Hovering a stack, it offered *what
  the stack is worth* and then also drew what the family's whole lot comes to — so on anything you
  had two of, the second answer was never announced.

- **Hold CTRL and ALT and click an item** — in your bags, in chat, anywhere the game lets a
  modified click through — and Family opens on every character who has one. The tooltip says so
  when it has had to shorten the list.

### Shorter lists stay whole

- **A list of ten or fewer is no longer contracted.** The crafting, reputations and possessions
  blocks used to show three and then *and 1 more*, which hides a name to save a line it then
  spends saying so. Reported by a French player.

- **Searching recipes across the whole family, or hovering a recipe, could stop with *script ran
  too long*** at the first such question after logging in. Every character's record was unpacked
  at that moment - half a second for thirty characters. They are now unpacked a few at a time in the
  seconds after you log in. Looking up each item name also asked the game for its version again; it
  now asks once.

- **And a list is only contracted when the page cannot hold it.** Where every block on the page fits,
  nothing folds, however long a block is. Where they do not, every block folds by the same amount -
  as little as brings the page back to one screen, and never below three.

### What a character is wearing counts as theirs

- **Gear is part of possessions now.** Hover a sword one character keeps in the bank and another
  wears, and Family says you have two of them — one in the bank, one equipped. It was always
  recorded and never counted.

- **It is drawn on the Possessions page**, first, as its own block, and it counts towards what
  that character's things are worth.

- **That block wears the character's own face** — their race and gender, from the game's own
  artwork, on the clients that have it.

### Reading the auction house

- **On Mists of Pandaria the whole auction house is read in one go.** That version answers its
  entire list to a single request — tens of thousands of listings at once — so there is nothing to
  page through and nothing to wait for. The same button starts it.

- **`/family ah scan go` walks every page of what the auction house last searched for** and
  remembers what everything is going for. It is off unless you ask for it, it tells you how far it
  has got, and `/family ah scan stop` ends it. On a busy realm this is thousands of pages and takes a while —
  it goes exactly as fast as the server answers, and everything it has already read is kept if you
  stop it or walk away.

- **A button on the auction house window reads the whole house**, so you never have to type
  anything. It clears the search first — otherwise it would read only what you last searched for —
  then searches and walks every page there is. The same button stops it. It sits beside Reset on
  the Browse panel. On Mists of Pandaria there is no such window and no button —
  that version has no pages to walk.

- **It says how long it has been going and roughly how long is left**, worked out from the pages
  it has already read rather than from a guess, so you can decide whether to wait for it. When it
  finishes it says how much of that was waiting for the server.

- **If another addon loads the whole auction house, Family reads it too — for nothing.** Some
  auction addons fetch every listing in one request. Whatever that puts on screen, Family now goes
  through it a slice at a time and keeps the prices, without sending a single request of its own.
  On a house of 178,000 listings that is thousands of prices you did not wait for.

- **And it no longer makes that scan worse.** Family used to re-read the whole list every time the
  game said the list had changed, which on an ordinary search is fifty rows and during one of those
  scans is very much more. That is what the slices replace.

- **It works out for itself whether it read the house or a search**, from the search the auction
  house actually sent rather than from whether the Reset button would take a click. It used to say
  the form could not be emptied when the form was simply already empty.

- **It will not touch a query another auction addon just made.** Some of them ask the game for the
  entire auction house in a single request; Family never does that, and it now refuses to reuse
  such a request rather than repeating it thousands of times. Search the auction house yourself
  and start the read again.

- **A read that stops getting answers now ends itself** instead of sitting there looking busy.
  Whatever it has already taken is kept, and it says why it stopped and where the time went.

- **If it will not start, it now says which button to press.** Search the auction house once and
  turn one page, and the read has everything it needs: it replays the search you made rather than
  inventing one of its own.

### Vendor prices on item tooltips

- **What a vendor pays you**, on any item's tooltip, anywhere in the game. Off until you turn it
  on, in Options.

- **And what a vendor charges** — for the things Family has seen on a merchant's shelf. Open a
  vendor and Family reads what is on sale and remembers it, so the price is with you afterwards
  wherever you meet the item. An item you have never seen for sale gets no such line: Family would
  be guessing that anybody sells it.

- **Hold CTRL over a stack** in your bags and the tooltip says what the whole stack sells for.

- **Hold CTRL anywhere else** — at the auction house, at a vendor, over a link in chat — and the
  tooltip says what everything your characters are holding of that item is worth, with how much of
  it was reached at auction prices and how much at what a vendor pays. It is the question no other
  addon can answer, because no other addon knows what your alts have. Each character is valued at
  their own realm's market, and the guild bank stays out of it.
  The key can be pressed with the pointer already there. Only over a stack — a single item never
  offers the key.

- **What the auction house was last asking**, with how long ago beside it. Family reads it off
  the list while you search — it never asks the auction house for anything itself — and keeps it
  per realm and per side, because those are not the same market. The cheapest on show in one visit
  wins; your next visit replaces it, because a fortnight-old price is a photograph.

- **The higher price wins** when two of your characters see different ones, because a reputation
  discount only ever makes a vendor cheaper.

### Pets, for hunters and warlocks

- **A Pets page**, on Abilities & Talents: every pet in the stable and every demon you have
  summoned, with what that creature can do. The game only talks about a creature while it is
  out, so the page fills in one summon at a time and keeps what it has seen.

- **Training points, added up.** Each ability carries what it cost, and the creature says how
  much of what it has spent that accounts for — *273 of 273 Training Points accounted for*.

- **What a pet has left to spend**, in green on its row: the number you would go to a trainer
  about. A freshly tamed pet, which owes points until it is loyal, says so in red.

- **A Beast Training list you can read.** Every line says its rank, what it costs and what level
  the pet has to be, with the game's own tooltip on it — it used to be five rows all called
  *Arcane Resistance* with nothing to tell them apart. Open the window once on each hunter to
  fill it in.

- **The trainer's window is remembered between pets.** It only prices what the creature you have
  out can learn, so each visit now fills in what the last one could not see instead of wiping it.

### Sharing with another family

- **An interrupted share picks up where it stopped.** Logging out part way through — or closing
  the game, or the other person going offline — no longer leaves characters Family believes it
  has sent. Each side tells the other what it already holds.

- **The other side confirms what it received**, so *sent* becomes *confirmed* on the Wide Family
  panel. Anything never confirmed is simply sent again next time.

- **Starting a share no longer freezes the game.** A family of two hundred characters used to
  stop the client for several seconds while it packed, in the middle of play. It goes out a dozen
  characters at a time now.

- **Logging in with Wide Family on no longer pauses either of you** — a fifth of a second saved
  per exchange on fifteen shared characters, more than a second on the families that reported it.

- **A family who is offline costs almost nothing.** Family asks each of their characters with a
  single message instead of preparing a full update for somebody who is not there, and two
  characters of the same name no longer flood your chat while it works out which is which.

- **Answering their update is as light as asking for one**, and every message now carries as much
  as the game allows — about a seventh less waiting.

- **Update now says what is already on its way**, for that family, with a count that moves while
  you watch it, instead of quietly queueing a second copy behind the first.

### Fixed

- **Clicking a profession opens its window again.** The yellow note said it would and nothing
  happened: the button was built correctly and the game was simply not acting on it. Family now
  asks for the window itself as well.

- **Clicking a profession on the summary did nothing** until you had opened the Professions panel
  once in that session — after which it worked for the rest of it.

- **A low-level character's abilities page listed things they have not learned.** On Mists of
  Pandaria the spellbook draws every ability the class will ever get, greyed out, and Family was
  recording them all — so a level three hunter appeared to know Stampede and Trueshot Aura, with a
  nameless *Spell #9* among them — and the three specialisation tabs beside them, each listing
  that specialisation's whole repertoire, so one ability was drawn under several headings. Family
  now records what a character has, once. **Call Pet** and anything else the game hides behind one
  button is read out of it rather than left off. Each character corrects itself the next time you
  play them, and a linked family sees the correction after that.

- **A pet ability the trainer prices but Family would not.** Passive abilities are listed at a
  rank in the trainer's window and call themselves *passive* everywhere else, and Family threw
  the price away rather than match the two — which is why one Ravager's points came to 248 where
  the game said 273.

- **An ability that costs nothing now says so** instead of *no price known*, which is the other
  reason a pet's points did not add up.

- **A character played in two languages had two ability lists**, one in each. There is one now.

- **A stray colon in the middle of several sentences**, as *77 Training Points:*.

- **A key in your keyring now has a tooltip.** Hovering one on your own Possessions page showed
  nothing at all, while the same key on another character's page described itself normally.

### If you are reporting a problem

- **`/family ah`** says what your version of the game offers at the auction house and how many
  prices Family is holding for the realm and side you are on. **`/family spellbook`** walks the
  client's own spellbook and says, tab by tab, what Family reads
  from it and what it leaves alone — the answer to *why is this ability missing, or why is that one
  there*. **`/family pettp`** shows where a pet's training points went, and **`/family widetime`**
  says how many characters each link shares and how long an exchange spends on them. None of them
  scans anything, and none of them sends anything anywhere.
