# HANDOFF — Family: dopo la 5.2.0, voce 114 da correggere — 2026-11-20

Origine: Claude Code (sessione 53b917b9, `/home/dietpi/dev/Family-public`, `main`) · Destinazione prevista: Claude Code, stessa cartella

## Obiettivo
Il lavoro della sessione è chiuso: le voci 111 e 112 di `docs/BACKLOG.md` sono state corrette e pubblicate nella 5.2.0, e la voce 113 si è chiusa come falso allarme. Il prossimo lavoro è la **voce 114**, un difetto trovato solo leggendo il codice e mai visto in gioco: una lista lunga letta nella casa d'aste dei goblin finisce sotto la fazione di chi legge e non nel mercato neutrale.

## Contesto indispensabile
**La voce 114** (`docs/BACKLOG.md`, intestazione `## 114.`):
- In `addons/Family/Scanners/Auctions.lua`, `ReadPrices` sceglie il mercato con `readingMarket()`, che restituisce `realm\30*` quando `Auctions:HouseIsNeutral()` è vero.
- `bigReadTick` invece usa `market()`, cioè sempre `realm\30<fazione di chi legge>`, e passa quel valore a `readRows`.
- Così i prezzi di una lista lunga letta dai goblin non arrivano all'altra fazione attraverso il ripiego sulla casa neutrale (voce 66).
- I numeri di riga cambiano: cerca i nomi delle funzioni, non le righe.

**Come i prezzi sono salvati** (letto nel codice in questa sessione):
- `FamilyDB.auctionPrices["<reame>\30<fazione>"]`.
- `*` indica la casa neutrale, condivisa dalle due fazioni dello stesso reame.
- `?` indica una fazione che il client non ha restituito.
- `groupMarkets` unisce, solo in lettura, i mercati della stessa fazione e quelli neutrali dei reami connessi (voce 91). Lo store non si sposta.
- `Auctions:Prices(where)` crea una tabella vuota quando viene interrogato: da qui i mercati con 0 prezzi.
- L'unica riga che toglie un prezzo è `Forget` (`prices[variant] = nil`).

**Il gate di `docs/DECISIONS.md`** (`tools/decisions.py --check`, lanciato dall'harness):
- Una riga nuova supera al massimo **1000 caratteri**. Dal 2026-11-16 una riga più lunga è un **errore**, non più un avviso.
- Le parole di revisione (regex `REVISES`) obbligano la riga a citare un id `D-…` esistente, oppure a contenere la frase `no row replaced`.

**Gate prima di ogni commit:** l'harness del pre-commit (4301 check passati al commit `3733284`) e `tools/mutate.py --changed`. Prima di un rilascio serve il run completo di `tools/mutate.py`.

## Decisioni prese (e perché)
- **Ricerca della famiglia (111):** la chiave è `spell:<id>` da `recipe.spellID or recipe.matchedSpellID`, altrimenti `item:<id>\0<professione>`. Per la gilda la chiave è `item:<id>\0<riga>`. Così su Era, dove le righe hanno solo l'oggetto, due trasmutazioni che fanno la stessa essenza non si fondono più.
- **Scanner professioni (111):** abbina lo spell con la parola esatta quando c'è più di un creatore. Se resta un pareggio, `matchedSpellID` non viene impostato: meglio nessun dato che uno sbagliato.
- **Nomi (112):** `Names.lua` usa `recipe.spellID or recipe.matchedSpellID`, così chi gioca in un'altra lingua vede due nomi diversi.
- **Voce 113 chiusa senza modifiche:** due letture dal client del giocatore (Era, cluster Pyrewood Village / Mirage Raceway / Nethergarde Keep) hanno mostrato le fazioni salvate separatamente. Il giocatore ha poi scritto che si aspettava i prezzi delle due fazioni indicati a parte e li aveva scambiati per una sovrascrittura.

## Strade scartate (e perché)
- **Dare una causa alla 113 prima delle letture** → L-085 e L-207. La candidata "casa di fazione scambiata per neutrale su Era" è caduta: `*` conteneva 4 prezzi soli e non esisteva nessun mercato `?`.
- **Correggere `bigReadTick` dentro la 113** → è un difetto diverso, ora voce 114.

## Stato
**FATTO**
- **5.2.0 pubblicata** (`a033868`): contiene la 111 e la 112, e lo SMOKE l'ha compilato Alberto su tutti e quattro i client (`4705d09`).
- **`c757c4b`:** `tools/mutations/caught-by.tsv` aggiornato dal run completo del rilascio.
- **`3733284`:** voce 113 chiusa e voce 114 aperta. Pre-commit a 4301 check passati.
- Questo `HANDOFF.md`, da committare.

**IN CORSO**
- Niente.

**BACKLOG** (in ordine)
1. **Voce 114.** Correzione in `bigReadTick`, più un check nell'harness (vedi PROSSIMA AZIONE), una mutazione in `tools/mutations/`, una riga nell'**Unreleased** di `CHANGELOG.md` e una riga in DECISIONS.
2. **Push:** `main` è avanti di almeno 2 commit su `origin/main` (`c757c4b`, `3733284`), più quello dell'handoff. Il push lo decide Alberto.
3. **Conferma in gioco** della 111 e della 112: nelle intestazioni sono ancora "not yet seen in game".
4. **Pagina *Files* di CurseForge per la 5.2.0:** non l'ho controllata io.
5. **Possibile richiesta UX, non registrata:** indicare la fazione accanto a un prezzo d'asta. Il giocatore della 113 se la aspettava. Non l'ha chiesto né Alberto né il giocatore come funzione, quindi chiedi ad Alberto prima di aprire una voce.

## Artefatti
| Artefatto | Dove | Stato | Leggibile? |
|---|---|---|---|
| Voci 111–114 | `docs/BACKLOG.md` | 111/112 DONE, 113 CLOSED, 114 OPEN | sì |
| Codice delle aste | `addons/Family/Scanners/Auctions.lua` | da correggere (114) | sì |
| `addons/Family.zip` | root | non tracciato, **non nostro**: non toccarlo | sì |
| `docs/images/)à'.png` | non tracciato | **non nostro**: non toccarlo | sì |

## Regole di lavoro concordate in questa chat
- **Lingua:** con Alberto si parla in italiano. Repository, codice, commit e documenti sono in inglese.
- **Stile:** risposte concise. Per le scelte riservate, opzioni numerate con una raccomandazione; Alberto risponde spesso con il solo numero.
- **Riservati (si chiede sempre prima):** licenza, librerie di terzi o nuove fonti dati, riscrittura della storia, rendere pubblico il repository, condivisione accesa di default, push di un tag `v*`, cancellazioni dall'albero, righe `allow` in `~/.config/family/words`.
- **Push:** lo decide Alberto. Si committa solo quando lo chiede lui.
- **Comandi del gioco** (`/family …`, `/run …`): mai dentro un blocco bash. Una riga `/run` si conta (con `/run ` sotto i 255 caratteri, L-127), si compila con `luac5.1 -p` e non deve contenere sequenze `_,_` (L-032).
- **Segnalazioni dei giocatori:** prima chiedere le parole esatte del giocatore e una lettura, poi parlare di causa.
- **Dove non si scrive:** mai in `/mnt/RemoteBU1`. I file temporanei vanno nella scratchpad della sessione, mai nell'albero.
- **Parole bandite:** mai scrivere nell'albero una parola di `~/.config/family/words`.

## Problemi aperti / dubbi
- La 114 è stata trovata leggendo il codice, non in gioco. Non è dimostrato che una lista lunga venga mai letta dai goblin su un client reale. Il check dimostra il codice, non il gioco.
- La lettura di `HouseIsNeutral` su Era (`target` in una casa di fazione) non è stata misurata con `/family ah`. Le letture della 113 la rendono improbabile come guasto, ma non la misurano.

## PROSSIMA AZIONE
Leggi la voce 114 in `docs/BACKLOG.md` e, in `Auctions.lua`, le funzioni `bigReadTick`, `readingMarket` e `ReadPrices`. Poi dichiara ad Alberto i file da toccare e scrivi prima il check. Il check deve avviare una lettura lunga con l'evento vero attraverso il dispatcher (L-005), con il banditore senza fazione. Deve poi verificare che i prezzi finiscano in `realm\30*` e non nel mercato della fazione di chi legge, e va visto fallire prima della correzione (L-088).

## Verifica
1. In quale mercato deve finire una lista lunga letta dai goblin, e quale funzione la mette oggi nel posto sbagliato?
2. Perché la voce 113 è stata chiusa senza toccare il codice?
3. Una riga nuova in DECISIONS di 1100 caratteri oggi passa?
4. Chi fa il push, e quanti commit locali aspettano?
5. Cosa non va mai scritto dentro un blocco bash?
