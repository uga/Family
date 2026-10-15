# Family - decisions replaced

Which decision in `docs/DECISIONS.md` a later one replaced, written by hand: it is a judgement,
not something a script could derive, so it is committed. An id is the one `tools/decisions.py`
computes from the row; nothing is written into the decisions file itself.

- `- D-old → D-new` - the old decision is no longer in force, and `--file` leaves it out.
- `- D-old → D-new (in part)` - the new row changed part of the old one, which stays in force;
  every answer that shows the old row names the new one beside it.

Each pair has its reason on the line under it. A row that replaces another names the old id
and adds its pair here in the same commit. The pairs from before 2026-10-15 were recovered from
the rows that cite another row or call themselves a correction, and from no others.

- D-2026-08-26-80d3bc → D-2026-08-26-5f8a2e
  The transformation of `workshop` into `sanitised` ended with the seed; the row records how publication happened.
- D-2026-08-26-b5a03b → D-2026-08-26-5f8a2e
  The sanitisation's reach ended with the transformation it belonged to.
- D-2026-08-26-4abc86 → D-2026-08-26-5f8a2e
  The seed was taken; the row records how the public repository began, not how work continues.
- D-2026-08-30-f9dd04 → D-2026-08-30-75071b
  Reopening where it was left became opening on a starred panel, the same day.
- D-2026-08-30-8eae5c → D-2026-08-30-60faa9
  Automatic guild profession sharing was reversed before anything was built; the per-profession grid stays.
- D-2026-08-30-bd18cb → D-2026-08-30-5bd8b7
  The buffs banked in a Chronoboon are readable after all, from the aura's tooltip line 2 read whole.
- D-2026-09-04-5dc81e → D-2026-09-05-8ce565
  A name carries its realm when the character is not on the realm being played, not whenever the account spans realms.
- D-2026-09-04-668906 → D-2026-09-05-5be7ad
  The whole-family reputation view became a faction and its people, three at a time.
- D-2026-09-01-17b831 → D-2026-09-05-e1b205
  A ready crafting item is announced at login beside the crafts.
- D-2026-09-07-85b299 → D-2026-09-07-3f8a54
  A pet or demon ability is stored by spell id, read from a scanning tooltip, with the book's word beside it.
- D-2026-09-10-914220 → D-2026-09-12-04d2e0
  Every money figure on an item tooltip is in full gold, silver and copper; the short form stays for the mail report only.
- D-2026-08-28-ff2e18 → D-2026-09-13-6c8ee5
  A Wide Family link reaches the character's connected realm group, not any realm.
- D-2026-08-30-3ca089 → D-2026-09-13-b04b1a
  Update now sends the difference; a full resend is `/family wide resend`.
- D-2026-09-14-674f2c → D-2026-09-14-befaae
  Bid value and Buyout keep their copper; only Worth goes without it.
- D-2026-09-15-35c269 → D-2026-09-15-9dae0a
  The gold-only change was discarded uncommitted; the audit page gives each item two lines instead.
- D-2026-09-20-6a4574 → D-2026-09-20-0c81a8
  The tiered gate is in force on this branch too, from Alberto directly.
- D-2026-09-22-71c364 → D-2026-09-22-017a79
  A cursor over several nodes answers about each of them, deduplicated, instead of giving no answer.
- D-2026-09-23-eaa30f → D-2026-09-23-032f4b
  An empty currency list on Mists was one character owning no currency, not the build; backlog 103 withdrawn, 102 reopened.
- D-2026-09-26-274b5d → D-2026-09-26-3660b1
  Starred currencies went back to one set for the account, within the hour.
- D-2026-09-27-456146 → D-2026-09-27-03dfef
  The per-character transmog collection was withdrawn as unsettled; the probe then measured it account-wide.
- D-2026-09-27-d9899a → D-2026-09-27-813bf6
  Backlog 108's shape was chosen again on the measured premise: uncollected looks the family owns.
- D-2026-08-30-e3eccb → D-2026-08-30-19185f (in part)
  The money scope also changes on shift + left click, not only on a middle click.
- D-2026-09-06-fcdf52 → D-2026-09-06-b2ea9b (in part)
  Riding came off the professions panel entirely, which made the picker's own refusal dead code.
- D-2026-09-12-e55b71 → D-2026-09-12-ee8e26 (in part)
  The claim of no unread rows is struck: close to a third of a loaded list gives back no item.
- D-2026-09-13-cb9302 → D-2026-09-13-1aa922 (in part)
  The explanation of 271 of 289 lists in another language was not measured; the probe was counting skills.
- D-2026-09-13-c2ffe2 → D-2026-09-13-64baa4 (in part)
  Choice (c): the first exchange after updating sends every member once, not only characters played.
- D-2026-09-06-06372b → D-2026-09-13-b04b1a (in part)
  The clause that `full` is the Update now button and only that: Update now no longer sends `full`.
- D-2026-09-15-141352 → D-2026-09-15-d83aaf (in part)
  The Mirage Raceway Worth total is four members, not five.
- D-2026-09-15-2eb02e → D-2026-09-15-037b38 (in part)
  The audit page was slow to scroll; the decent-speed remark is taken back.
- D-2026-09-15-f26041 → D-2026-09-15-90fecc (in part)
  A ban no longer clears the price already held; it keeps the price out of Worth and recipe costs.
- D-2026-09-15-c26fac → D-2026-09-15-90fecc (in part)
  The filing routes no longer refuse a banned price; they file it as before.
- D-2026-09-15-f2359c → D-2026-09-15-a6678e (in part)
  Backlog 79's line moved above the grid; nothing else about 79 changed.
- D-2026-09-12-96f899 → D-2026-09-19-e477cb (in part)
  A bound material is costed from its recipe only where one of our own characters knows that recipe.
- D-2026-09-19-b8d821 → D-2026-09-19-257233 (in part)
  The slow-route line shows the total the slower way would come to, not the difference.
- D-2026-09-18-b069e8 → D-2026-09-19-27be07 (in part)
  The probe's `.toc` carries Midnight's interface number, 120100, not none.
- D-2026-09-19-7cb77b → D-2026-09-19-77f446 (in part)
  The no-argument sweep runs on Midnight and on no other client.
- D-2026-09-20-0d5408 → D-2026-09-20-415292 (in part)
  The probe did not cancel Alberto's auction; he cancelled it himself.
- D-2026-09-20-3b39ee → D-2026-09-20-a12d02 (in part)
  The renumber's permanent damage is six commits wide, not three.
- D-2026-09-20-3b39ee → D-2026-09-20-c99982 (in part)
  The collision is seven commits and one number older than recorded: L-103 answers twice.
- D-2026-09-21-324e7f → D-2026-09-21-4b4af1 (in part)
  Tontazzo's reading does not confirm the quarter rate to the point; it was scored on an interval nobody recorded.
- D-2026-09-23-fe1c83 → D-2026-09-23-e68214 (in part)
  With nobody locked, the lockouts section stays and says so in grey.
- D-2026-09-26-638f66 → D-2026-09-26-f37df8 (in part)
  Midnight's first release keeps only what Forever will also have: crafting orders, delves and the keystone wait.
- D-2026-09-26-18562f → D-2026-09-26-274b5d (in part)
  Stars kept per character being played rather than for the account (itself replaced within the hour).
- D-2026-09-26-91166a → D-2026-09-26-88c570 (in part)
  Midnight's stabled pets are read at every scan, not only at the stable master.
- D-2026-09-27-deec95 → D-2026-09-27-60b5e3 (in part)
  The full-size guild tab was seen on Midnight, not Mists.
- D-2026-09-27-1aeaf1 → D-2026-09-27-f8d571 (in part)
  One new check, not two.
- D-2026-09-28-0d08e4 → D-2026-09-28-5dd2d3 (in part)
  A profession's tools and accessories are one strip of boxes behind a label, between the headings and the recipes.
- D-2026-10-13-210910 → D-2026-10-13-39eec7 (in part)
  The Summary's Expires in shows the next letter that can still be collected; the gone cell is no longer unchanged.
- D-2026-10-15-ab31c3 → D-2026-10-15-488d7d (in part)
  The lessons gate has eight recorded mutations, not nine.
- D-2026-10-15-916f20 → D-2026-10-15-32fd67 (in part)
  What the hook row says of `cmd:` triggers: they match the command a step runs, from its first word.
