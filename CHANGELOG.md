# Family — changes

What changed in each release, in the words a player needs rather than the words a commit
message uses. `tools/release.sh` cuts the top section into the release notes CurseForge shows.

Newest first. Anything under **Unreleased** is written as it lands, so that cutting a release
is a decision rather than an afternoon of archaeology.

---

## Unreleased

### Added

- **Mail in the post has a column of its own.** It used to be a phrase inside the mail column
  — *1 (1 in post)* — which did not fit that column in English and fitted it in no other
  language at all. It is now its own number beside the mailbox count, and it no longer hides
  when a mailbox has never been looked at, which is the half of it that is known without one.
- **Family speaks German, French, Spanish and Russian.** Every screen, every slash command,
  the manual it carries and the messages it prints. Anything not yet translated falls back to
  English rather than to a blank, so nothing can go missing; and where the game already has a
  word for something — a gear slot, a reputation standing, a class, the glyph list — Family
  uses the client's own word rather than one of its own, which means it says what the rest of
  your interface says, in all eleven languages the client ships in.
- **Panels give way to longer words.** Every fixed column width in Family was chosen by
  looking at English, and English is the shortest of the five languages it now speaks. A
  column too narrow for its own heading is widened and the room is taken from whatever has
  most to spare, so a translated heading is never drawn through the column beside it.

### Fixed

- **A guildmate who is running Family is no longer listed as not running it.** Family only
  knows somebody runs it by hearing from them, and a client that already had your characters
  answered your announcement with silence — correctly, to save the channel, but that silence
  was the only thing it ever sent you. It now says hello back. This shows up most for anyone
  who has cleared their saved data or reinstalled, whose guild then looked empty.
- **Recipes are shown in your own language too.** Professions learnt to say *Secourisme* and
  then listed twelve recipes in English underneath, because the list had been read on an
  English client. Family records what each recipe makes, so it now asks your own client what
  that is called rather than repeating the word it was written down in. Nothing needs
  rescanning — lists already saved read correctly as soon as you reopen the panel. Clicking
  such a recipe works again too: it looks for the row in your open profession window, and it
  had been looking for a word that window does not use. Searching finds them under either
  name.
- **A recipe list no longer comes back half translated.** Names came from the item each recipe
  makes, and the game only knows an item once it has loaded it — so a first aid list arrived
  half in one language and half in the other. Family now asks for the ones it is missing and
  redraws when they arrive.
- **A recipe you recorded in your own language keeps the words the game used.** Smelting is
  where this shows: the game calls the row *Smelt Copper* and the thing it makes is a Copper
  Bar, and Family had started saying the second.
- **Clicking a recipe with no window open names the button to press**, rather than printing a
  number nobody can act on.
- **Professions are no longer reported as "recorded in another language" when they simply have
  no recipes.** Fishing, herbalism, mining and skinning have no window to open, and one member
  with a list in another language had them all reported that way.
- **The line saying which professions were left out now wraps** instead of running off the right
  edge — the half that fell off was the half saying why.
- **Professions read in your own language before you have rescanned them.** A character is only
  re-read when you log in on them, so a family part-way through showed some members' professions
  in French and others in English on the same screen. The recorded word is one Family knows, so
  it is now translated on sight — the rescan still matters for recipe lists, but not for this.
- **Races are shown in your own language, whoever recorded them.** A character last played on
  a French client stayed French on a Spanish one, and a member shared with you was named in
  whatever their owner was running. Family now reads the game's own race table, so it says
  what your client says — and where your own client wrote the word, that word is kept, gender
  and all. Nothing needs rescanning for this one.
- **The undead are undead.** Where Family had no word for a race it fell back to the internal
  file string, which calls them *Scourge* and night elves *NightElf* — words the game shows
  nobody.
- **The minimap total agrees with the tooltip under it.** The figure on the bar was worked out
  once at login and never again, so it drifted from the tooltip and the summary by however
  much you had spent since. It is now brought up to date whenever anything changes.
- **Dates take less room.** *19 days ago* is now *19d ago*, matching the *in 19d* the other
  columns already used — the long form was wide enough to be cut off in the activity row.
- **Professions are the same profession in every language.** Family used to file them under
  their name, because Classic Era offers nothing else to file them under — so the same
  character read on a French client and a Spanish one had two sets of professions, and neither
  could see the other's recipes. They are now filed under the game's own skill line id, taken
  from the client's own tables, and shown in the language of whoever is reading. A member
  shared with you by a German player lands under the same key as everybody else.
  **Rescan your professions once** by opening each window; there is nothing to migrate.
- **A profession recorded in one language is no longer reported as never opened.** Family
  stores a profession by its name, because on Classic Era the game offers nothing else to
  store — so a character keeps the words it was last played in until you log in on it again,
  and its recipe lists keep whatever language their window was last opened in. Where those
  disagreed, the panel found nothing under the name it was looking up and said the profession
  had never been opened, while holding every one of its recipes. It now says so, and says that
  logging in on that character will put it right. Nothing was ever lost.

### Changed

- **The minimap tooltip groups characters by realm and then by side.** An Alliance character
  and a Horde one on the same realm share no bank, no mailbox and no auction house, and a
  single list of them read as one pool of characters that could pass things between them. Each
  side now carries its own count and its own money, the way the summary has always shown it.
- **Anything Family counts is now phrased for the language it is in.** Fifteen messages built
  their plural by hanging an "s" on the end of a word, which is a plural in English and in
  nothing else.

- **Wide Family is described as what it is: off by default.** It shipped with a warning that
  none of its checks had run against a real server, which was true when it was written and
  stopped being true when the live pass reached it on all three clients. It is still off until
  you ask for it — sharing is the one thing a later version cannot take back — but that is now
  a choice about consent rather than a caveat about testing. The About panel, `/family wide`
  and the manual all say the same thing.

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
