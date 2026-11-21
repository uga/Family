# HANDOFF — Family: 114 e 115 pubblicate su main, voce 116 da studiare — 2026-11-21

Origine: Claude Code (`/home/dietpi/dev/Family-public`, `main`) · Destinazione prevista: Claude Code, stessa cartella

## Obiettivo
Questa sessione ha chiuso le voci 114 e 115 di `docs/BACKLOG.md` e ha spinto tutto su `origin/main`. Il prossimo lavoro è la **voce 116**: scrivendo nella cassetta delle lettere il nome di un personaggio della famiglia, Family completa `Nome-Reame` e la lettera parte senza l'attesa di 3 secondi del dialogo «forse non conosci questa persona». La voce non è stata iniziata: prima vanno lette dal client alcune cose (vedi PROSSIMA AZIONE).

## Contesto indispensabile
**La richiesta di Alberto, testuale** (è anche nella voce 116):

> when sending mail to a family member, typing its name at the mailbox will automatically find the Name-Server of the characters from the same family, and allows to send mail without having the boring 3 seconds timer "Maybe you don't know this person, etc...

**Cosa dice la voce 116 sul prima di costruire:** su ciascun client va letto che cosa la casella di invio accetta e completa già da sola, a quale dialogo appartiene l'attesa e se un addon può rispondergli. Va letto dal client, non dato per scontato (L-020, L-026). Non si sa se saltare quel dialogo sia permesso: ad Alberto non è stato promesso.

**Codice della posta** (`addons/Family/Scanners/Mail.lua`):
- `memberNamed(recipient)` trova il membro da un nome scritto, con o senza `-Reame`, senza distinguere maiuscole e minuscole. Probabilmente è il pezzo da riusare.
- L'invio è osservato con `hooksecurefunc("SendMail", …)` e confermato su `MAIL_SEND_SUCCESS`.

**Gate prima di ogni commit:** l'harness del pre-commit (4306 check al commit `6f1ac86`) e `tools/mutate.py --changed`. Prima di un rilascio serve il run completo di `tools/mutate.py`.

## Decisioni prese (e perché)
- **114:** `ReadPrices` salva in `bigRead.where` il mercato che sceglie, e `bigReadTick` usa quello. Interrogare il banditore a ogni tick lascerebbe decidere a un bersaglio cambiato a metà dove va il resto della lista. Riga in `docs/DECISIONS.md` del 2026-11-20.
- **115:** è stata scelta da Alberto l'opzione 1 di tre. La scansione della cassetta tiene una lettera «in viaggio» se è stata spedita meno di un'ora fa (`DELIVERY = 3600`) e nessuna lettera della cassetta ha gli stessi soldi e gli stessi oggetti (id e quantità, in qualsiasi ordine). Ogni lettera della cassetta ne copre una sola. Dopo un'ora, una lettera che non si è vista viene lasciata cadere. Riga in DECISIONS, specifica §5 aggiornata.
- **115, perché non serviva misurare quali lettere la posta trattiene:** una lettera arrivata subito è nella cassetta e viene abbinata lì.

## Strade scartate (e perché)
- **Check della 115 accanto a quelli d'invio** ("mail posted to another member"): lì `advance` fa partire una ventina di timer lasciati in sospeso dalle sezioni precedenti (`guild.hello`, `wide.queue`, `comm.probation`…) e manda in rosso i check dei whisper più avanti. I check stanno nella sezione "the mailbox", dove `fire` + `advance` sono già normali.
- **Scansione «un'ora dopo» spostando `time()` in avanti con gli eventi:** scriveva nel record del membro giocato e rompeva l'ordinamento per denaro. Il check dell'ora dopo usa una `Scan()` diretta con l'orologio spostato, come faceva il check originale.

## Stato
**FATTO**
- `ee69715`: voce 114 (asta neutrale, liste lunghe), 2 check e 2 mutazioni.
- `6f1ac86`: voce 115 (lettera in viaggio), 3 check e 5 mutazioni `a-letter-*.mut`. La voce 116 è aperta.
- Push di `main` su `origin` (`a033868..6f1ac86`), senza tag. `main` è allineato a `origin/main`.
- Questo `HANDOFF.md`, ancora da committare.

**IN CORSO**
- Niente.

**BACKLOG** (in ordine)
1. **Voce 116**, vedi PROSSIMA AZIONE.
2. **Conferma in gioco** della 111, 112, 114 e 115: nelle intestazioni sono ancora "not yet seen in game". Per la 115: spedire oggetti da A a B, poi aprire la cassetta di B entro l'ora. Per la 114: caricare tutta la casa d'aste dal banditore goblin.
3. **Pagina *Files* di CurseForge per la 5.2.0:** nessuno l'ha controllata.
4. **Possibile richiesta UX, non registrata:** mostrare la fazione accanto a un prezzo d'asta. Va chiesto ad Alberto prima di aprire una voce.

## Artefatti
| Artefatto | Dove | Stato | Leggibile? |
|---|---|---|---|
| Voci 114–116 | `docs/BACKLOG.md` | 114/115 DONE, 116 OPEN | sì |
| Lettura del ritardo della posta | `docs/DATASOURCES.md`, *How long the post holds a letter…* | Era, oggetti, stesso account; il resto non è misurato | sì |
| `addons/Family.zip` | root | non tracciato, **non nostro**: non toccarlo | sì |
| `docs/images/)à'.png` | non tracciato | **non nostro**: non toccarlo | sì |

## Regole di lavoro concordate in questa chat
- **Lingua:** con Alberto si parla in italiano. Repository, codice, commit e documenti sono in inglese.
- **Stile:** risposte concise, e opzioni numerate con una raccomandazione. Alberto risponde con il solo numero: se il numero non corrisponde a nessuna domanda, chiedi di nuovo, non indovinare.
- **Commit e push:** solo quando lo chiede lui. Il push di `main` non è riservato; il push di un tag `v*` sì.
- **Riservati (si chiede sempre prima):** licenza, librerie di terzi o nuove fonti dati, riscrittura della storia, rendere pubblico il repository, condivisione accesa di default, tag `v*`, cancellazioni dall'albero, righe `allow` in `~/.config/family/words`.
- **Comandi del gioco** (`/family …`, `/run …`): mai dentro un blocco bash. Una riga `/run` si conta (con `/run ` sotto i 255 caratteri, L-127), si compila con `luac5.1 -p` e non contiene `_,_` (L-032).
- **Segnalazioni:** prima il client (L-059) e una lettura, poi la causa.
- **Un check nuovo** si vede fallire prima della correzione, e la sua mutazione si registra (L-088). L'orologio di una sezione si muove a minuti interi (L-125).
- **Dove non si scrive:** mai in `/mnt/RemoteBU1`. I file temporanei vanno nella scratchpad della sessione.

## Problemi aperti / dubbi
- **115:** una lettera più vecchia, con contenuto identico, già nella cassetta può coprire quella nuova. In quel caso la nuova non si vede finché non arriva, ma non viene mai contata due volte. È accettato e scritto nel codice.
- **Ritardo della posta:** l'ora viene dal racconto di Alberto (Era, oggetti, stesso account), non da una misura. Lettere di soli soldi, account diversi e altri client non sono stati misurati.
- **Riga DECISIONS della 115:** dice "landed: `docs/BACKLOG.md`" perché è stata scritta prima del codice. DECISIONS è append-only, quindi non va corretta modificandola.
- **116:** non si sa se un addon può rispondere al dialogo con l'attesa, né su quali client compare.

## PROSSIMA AZIONE
Leggi la voce 116 in `docs/BACKLOG.md` e la parte «Posting to one of your own» di `Mail.lua`. Poi prepara per Alberto le letture da fare in gioco, una per client, come righe `/run` contate e compilate. Devono dire due cose: quale dialogo compare inviando a un personaggio dello stesso account su un altro reame o senza reame, e cosa offre già il completamento della casella di invio. Niente codice finché quelle letture non sono tornate.

## Verifica
1. Per quanto tempo la scansione tiene una lettera in viaggio, e con quali campi la abbina a quella arrivata?
2. Perché i check della 115 non sono accanto ai check d'invio?
3. Alberto risponde «2» a una domanda che non ha opzioni numerate: cosa fai?
4. Il push di `main` va chiesto? E quello di un tag `v*`?
5. Cosa va letto prima di scrivere codice per la 116?
