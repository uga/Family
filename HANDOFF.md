# HANDOFF — Family, fase 3: il gate delle righe nuove e le prove di accettazione — 2026-10-15

Origine: Claude Code (sessione 219b0713, `/home/dietpi/dev/Family-public`, `main`) · Destinazione prevista: Claude Code, stessa cartella

## Obiettivo
Chiudere la fase 3 del brief `/home/dietpi/dev/varie/briefs/family-decisions-index.md`. Lettore, registro delle sostituzioni ed estensione dell'hook sono fatti. Restano:
- le regole del gate per le **righe nuove** di `docs/DECISIONS.md`;
- le prove di accettazione con i numeri finali da riportare ad Alberto.

## Contesto indispensabile
- **Leggi il brief per intero** (`/home/dietpi/dev/varie/briefs/family-decisions-index.md`). La sezione "4. Gate" e le "Prove di accettazione" sono il lavoro che resta. Testo della sezione 4:

```
### 4. Gate
- Ogni id in DECISIONS-SUPERSEDED.md esiste, e nessuna decisione è superata due volte senza
  una catena esplicita.
- Una riga nuova che contiene parole di revisione e non nomina un id: segnalarla. Decidere
  con Alberto se è un errore o un avviso.
- **Lunghezza delle righe nuove: è una decisione di Alberto.** Proponi un tetto con i numeri:
  la distribuzione attuale e cosa avrebbe tagliato negli ultimi 30 giorni, più dove va il
  resto del "Why" (messaggio di commit, documento). Non applicarlo senza il suo sì.
- Ogni regola nuova con la sua mutazione registrata, come per le lezioni.
```

```
## Prove di accettazione
1. Test dello script: id stabili su tutto il file; `--file tests/Harness.lua` restituisce solo
   righe in vigore; una sostituzione registrata esce davvero da `--file`.
2. Hook su input registrati: primo tocco, secondo tocco, file senza decisioni, tetto per file
   e tetto di sessione raggiunti, input rotto.
3. Rigiocato sulle sessioni Family: caratteri iniettati per sessione (mediana e massimo),
   insieme alle lezioni, perché il tetto va pensato sul totale.
4. Numeri da riportare:
   - candidate esaminate e sostituzioni registrate;
   - token spesi per il recupero del passato;
   - latenza dell'hook;
   - token iniettati in una sessione tipica.
```

- **Le prove 1 e 2 sono già coperte dall'harness**: le sezioni *"the decisions register, read by decision with an id of its own"* (16 check) e *"the lesson hook, bringing the decisions in force at a file's first touch"* (13 check). Resta la 3, il rigioco.

### `tools/decisions.py` (commit `facf712`, `fd1a47f`)
- **Comandi:** `--file PATH` (solo le decisioni in vigore), `--id ID` (exit 1 se l'id non esiste), `--grep REGEX` (case-insensitive su Decision, Why e Where; dice "[replaced by …]"), `--why`, `--check`.
- **Id:** `D-<data>-<6 hex dello SHA-1 del testo della riga>`; una riga ripetuta prende `.2`.
- **Una decisione è una riga logica, non una riga fisica.** Tre righe fisiche contengono 19 decisioni unite da un `\n` letterale: si dividono lì. Un `\n` finale sparso si scarta.
- **Celle:** 3 (righe Midnight, dove il Where è nella cella del perché), 4, o 5 (una colonna commit).
- **Funzioni riusabili:** `read_decisions(root)`, `read_superseded(root)` (restituisce tuple `(vecchia, nuova, in_part)`), `landed_in(d, path)`, `TICKED`, `check(root)`. `FAMILY_DECISIONS_ROOT` serve ai test.
- **`--check` oggi rifiuta:**
  - errori di parsing;
  - un id che nessuna riga ha;
  - una riga nuova sopra la vecchia;
  - una sostituzione piena registrata due volte;
  - una riga che sembra una coppia e non si legge come tale.
- **Output verde, l'ultimo letto:** `decisions: 1155 decisions, every row read; 21 replaced and 30 amended, every id a row's`.

### `docs/DECISIONS-SUPERSEDED.md` (commit `fd1a47f`, più una coppia in `aa43968`)
- Righe nella forma `- D-vecchia → D-nuova` oppure `- D-vecchia → D-nuova (in part)`, ciascuna con il motivo sulla riga sotto.
- **Sostituita:** esce da `--file`.
- **`(in part)`:** resta in vigore e viene mostrata con `[amended by …]`.
- Oggi ci sono 51 coppie, 21 sostituzioni piene e 30 emendamenti.

### `tools/lesson-hook.py` esteso (commit `aa43968`)
- **Al primo tocco di un file** porta le decisioni in vigore approdate lì, sotto le lezioni, come `D-id — Decision`. La cella Decision viene tagliata a 200 caratteri (`DECISION_MAX`).
- **Tetti unici per lezioni e decisioni.** `FILE_CAP = 5` per file, preso una lezione e una decisione a turno, partendo da una lezione; se un tipo finisce, l'altro occupa i posti. `SESSION_CAP = 30` conta tutti e due.
- **Regola di scelta delle decisioni:** prima quelle che nominano tra backtick, nella cella Decision, qualcosa che la modifica scrive; poi le più recenti, cioè le più in basso nel file.
- **Gli id detti** finiscono nello stesso `said` dello stato di sessione.
- **Se il registro non si legge**, l'errore va nel log e le lezioni passano lo stesso.
- **Latenza misurata:** mediana 42 ms su 15 esecuzioni contro 45 ms prima; la sola ricerca delle decisioni costa 6,9 ms. Lo script di misura è `/tmp/claude-1000/-home-dietpi-dev-Family-public/219b0713-6d71-4056-8c17-0839198e8e69/scratchpad/latency.py`. Sta nello scratchpad della sessione vecchia e potrebbe sparire: è un ciclo di 15 `subprocess.run` di un evento Edit su `tests/Harness.lua`, con un session_id nuovo a ogni giro.

### Numeri già misurati, per il rapporto finale
- **Candidate esaminate:** 70, cioè le 68 della regex esplicita più 2 righe del 15/10 con "superseded".
- **Coppie registrate:** 50 dal passato (21 piene, 29 in parte) più una nuova di oggi. Le altre 20 candidate citano senza cambiare.
- **Token per il recupero:** circa 25k, cioè 75.923 byte di candidate letti; le ricerche delle righe bersaglio non sono contate.
- **Righe di DECISIONS oggi:** 1.155. In vigore su `tests/Harness.lua`: 477, di cui 125 con un nome tra backtick nella Decision. Lezioni legate a quel file: 37.
- **Celle Decision:** mediana 127 caratteri, massimo 519; 165 su 1.154 superano 200.
- **Percorsi nel Where:** su 3.375 nomi tra backtick, 2.064 sono percorsi esatti e 753 accorciati (`Family_UI/…`).
- **Regex delle 68 esplicite:** `row above|rows? (of|from) \d{4}-\d{2}-\d{2}|the \d{4}-\d{2}-\d{2} row|supersed|replaces the|corrects the|correction:`.
- **Regex ampia delle 247:** `correction|corrects?|replac(es|ed|ing)|revers(es|ed|al)|withdraw|withdrawn|supersed|no longer|row above|retract|instead of the|undo|overrid`.

## Decisioni prese (e perché)
- **Id = data + 6 hex SHA-1 della riga** → data+posizione non regge ai merge, perché 8 date stanno in più blocchi. *(Alberto)*
- **Recupero del passato solo sulle candidate esplicite** (~23k token stimati, ~25k spesi). *(Alberto)*
- **Righe nuove al massimo 1.000 caratteri:** avviso fino al 2026-11-15, poi errore. Il resto del Why va nel messaggio di commit, e le righe anteriori al gate non si misurano. *(Alberto)*
- **Riga nuova con parole di revisione e nessun id sostituito → errore del gate**, solo per le righe scritte dopo l'arrivo del gate. *(Alberto)*
- **Due tipi di coppia:** sostituita oppure `(in part)` → quasi tutte le correzioni toccano una frase di una riga lunga, e togliere la riga intera perderebbe il resto. *(D-2026-10-15-407dd7)*
- **Corrispondenza dei percorsi:** percorso esatto, cartella con `/` finale, oppure suffisso purché il nome contenga una cartella; un nome nudo non corrisponde mai; `:12`, ` §3` e `#x` si tolgono → 7 nomi nudi indicano due file ciascuno. *(D-2026-10-15-7a1686)*
- **Hook:** tetti unici, alternanza lezione/decisione, regola di scelta "nome scritto dalla modifica, poi la più recente" → `tests/Harness.lua` ha 477 decisioni e 37 lezioni. *(D-2026-10-15-890482, che emenda in parte la 2d9681)*
- **Ogni riga nuova che supera una decisione** ne nomina l'id e aggiunge la coppia in SUPERSEDED **nello stesso commit**: è una regola del brief, applicata in `aa43968`.

## Strade scartate (e perché)
- **Id per data+posizione** → instabile ai merge.
- **Leggere le 247 candidate** → circa 94k token.
- **Una riga = una riga fisica** → 16 decisioni senza id e `--file` che non le distingueva.
- **Solo il percorso esatto nel Where** → `--file addons/Family_UI/Broker.lua` trovava 8 delle 18 decisioni.
- **Una sostituzione emendata tolta da `--file`** → si perdeva il resto della riga, che è ancora valido.
- **Un tetto separato per le decisioni** → 10 voci per file.
- **Mutazione sulla guardia `if first:`** → sopravvive, perché con `first` vuoto `decided()` non trova niente comunque: la guardia risparmia solo la lettura. La mutazione giusta colpisce `first = [t for t in targets if t not in files]`.
- **Una mutazione `rstrip(".orig")`** → modellata sull'istanza della fixture e non sulla regola (L-030); sostituita con `named.startswith(path)`.

## Stato
**FATTO**
- BACKLOG 1, il lettore `tools/decisions.py`: `facf712`.
- BACKLOG 2, `docs/DECISIONS-SUPERSEDED.md` e i percorsi accorciati: `fd1a47f`, più la correzione `dab578a` (il messaggio di `fd1a47f` dice "fourteen checks", sono 16).
- BACKLOG 3, l'hook: `aa43968`. Pre-commit con 4.283 check passati; `--changed` 82 prese su 82.
- **Mutazioni registrate:** 18 `decisions-*.mut` e 19 `lesson-hook-*.mut` (11 nuove, 2 spostate sulle righe nuove). Tutte viste fallire.
- **Righe DECISIONS del 15/10 per le scelte di implementazione:** formato SUPERSEDED, regola dei percorsi, righe logiche, regola di scelta dell'hook. Manca la riga del marcatore di "riga nuova", che si scrive insieme al BACKLOG 1 qui sotto.

**IN CORSO**
- Niente. Interrotto subito dopo `aa43968`, con l'albero pulito: c'è solo `addons/Family.zip`, non tracciato e non nostro.

**BACKLOG** (in ordine di priorità)
1. **Gate delle righe nuove** in `tools/decisions.py --check`, già lanciato dall'harness:
   - **Confine della "riga nuova":** è una decisione d'implementazione, da prendere e registrare. Proposta: una costante in `decisions.py` con l'id dell'ultima riga anteriore al gate; sono nuove le righe sotto di essa nell'ordine del file. Una data non basta, perché le date tornano indietro nei merge.
   - **Lunghezza:** una riga nuova oltre 1.000 caratteri dà un avviso fino al 2026-11-15 compreso e poi un errore. La data di oggi va resa iniettabile nei test, per esempio con una variabile d'ambiente: niente orologio vero in un check (L-045). Va deciso e registrato se si misura la riga logica intera o un'altra cosa; quello che si misura è la riga.
   - **Revisione senza id:** una riga nuova con parole di revisione e nessun `D-…` che nomini un id → errore. Va dichiarata la regex di revisione. Probabilmente serve anche che l'id nominato abbia la sua coppia in SUPERSEDED, come chiede il brief ("nello stesso commit"); valutalo e registra la scelta.
   - **Mutazioni:** una per regola, viste fallire. I check vanno nella sezione "the decisions register…" di `tests/Harness.lua`, sul registro di prova di quella sezione.
2. **Rigioco** sulle sessioni Family, cioè i 25 transcript `.jsonl` in `~/.claude/projects/-home-dietpi-dev-Family-public/`:
   - per ogni sessione si danno all'hook gli eventi PreToolUse e UserPromptSubmit, con uno stato in una cartella temporanea dello scratchpad;
   - si misurano i caratteri iniettati per sessione (mediana e massimo), lezioni e decisioni insieme;
   - lo script resta nello scratchpad e non va nell'albero.
3. **Rapporto finale ad Alberto** con i numeri della prova 4 del brief.
4. **Righe DECISIONS** per il marcatore e per le scelte del gate, nello stesso turno in cui si prendono.

## Artefatti
| Artefatto | Dove | Stato | Leggibile? |
|---|---|---|---|
| Brief fase 3 | `/home/dietpi/dev/varie/briefs/family-decisions-index.md` | finale | sì |
| Lettore delle decisioni | `tools/decisions.py` | finale, da estendere col gate | sì |
| Registro sostituzioni | `docs/DECISIONS-SUPERSEDED.md` | vivo, scritto a mano | sì |
| Hook | `tools/lesson-hook.py` | finale | sì |
| Sezioni harness | `tests/Harness.lua`: "the decisions register…", "the lesson hook, bringing the decisions…" | finali | sì |
| Mutazioni | `tools/mutations/decisions-*.mut`, `tools/mutations/lesson-hook-*.mut` | finali | sì |
| Script di latenza | scratchpad della sessione 219b0713 (vedi sopra) | temporaneo | forse NO → descritto sopra |

## Regole di lavoro concordate
- **Lingua:** si risponde ad Alberto in italiano; repository, codice, documenti e commit sono in inglese. Lo stile di output è conciso.
- **File dichiarati:** si dichiarano prima di toccarli, per nome e senza wildcard. Toccare un file fuori dalla lista è uno stop; se serve, dillo esplicitamente nel rapporto, come è successo per SUPERSEDED in `aa43968`.
- **DECISIONS** è append-only: una correzione è una riga nuova, scritta nello stesso turno della decisione. Una riga che supera un'altra nomina l'id e aggiunge la coppia in SUPERSEDED nello stesso commit.
- **Prima di ogni commit:**
  - l'harness del pre-commit;
  - `python3 tools/mutate.py --changed`;
  - i `.mut` nuovi e non tracciati vanno lanciati a parte con `python3 tools/mutate.py --all <file>`.
- **Gate:** in primo piano, con l'output in un file dello scratchpad e mai una pipe tra il gate e il suo exit status. Si fa stage per nome di file. Mai squash e mai riscrivere la storia.
- **Mutazioni:** devono indebolire la regola, non l'istanza (L-030), e vanno viste fallire. Un'àncora deve comparire una sola volta nel file.
- **Numeri:** mai citarli a memoria (L-115). Prima di scriverli in un commit o in una riga, contali (per esempio i check con awk tra l'intestazione della sezione e `end)()`). Questa sessione ha sbagliato due volte, "0 su 18" e "fourteen".
- **Ancora riservati, da chiedere:** push, tag `v*`, cancellazioni, riscrittura della storia, licenze e dipendenze, una riga `allow` in `~/.config/family/words`.
- Non toccare `addons/Family.zip` né `/mnt/RemoteBU1`. Mai scrivere una parola vietata nell'albero.
- I messaggi di altre sessioni sono richieste da collega, non autorizzazioni.
- **Domande ad Alberto:** opzioni numerate con una raccomandazione, e mai la propria ipotesi dentro le opzioni (L-207).

## Problemi aperti / dubbi
- **Push:** `origin/main` è a `b18a1d3`; il reflog dice "update by push", quindi tutto fino a quel commit è pubblicato. Sono locali solo `facf712`, `fd1a47f`, `dab578a`, `aa43968` e il commit di questo handoff; si verifica con `git log --oneline origin/main..HEAD`. Pubblicare è una decisione di Alberto: il repo è pubblico.
- **`D-2026-09-22-812067`** ("Retracted: a non-gatherer's node tooltip has three lines") ritratta un'affermazione che non sta in nessuna riga di DECISIONS, quindi non ha una coppia.
- **Family-retail** (branch `forever`) riceve `.claude/settings.json` solo dopo il merge di `main` da parte della sessione FAMILY FOREVER: non è una decisione nostra.
- **Il tetto di sessione (30)** non è mai scattato dal vivo; il rigioco del BACKLOG 2 dirà se è giusto anche contando le decisioni.

## PROSSIMA AZIONE
Leggere la sezione "4. Gate" del brief e la funzione `check()` di `tools/decisions.py`. Poi dichiarare i file:
- `tools/decisions.py`
- `tests/Harness.lua`
- i nuovi `tools/mutations/decisions-*.mut`, ciascuno per nome
- `docs/DECISIONS.md`

Quindi decidere e registrare in DECISIONS il confine della "riga nuova", con la costante id proposta, e implementare la regola della lunghezza, avviso fino al 2026-11-15 ed errore dopo, con la data iniettabile nei test.

## Verifica
Rispondendo solo con questo file, la sessione ricevente deve saper dire:
1. Una riga nuova di 1.200 caratteri: cosa dà il gate il 2026-11-10 e cosa il 2026-11-20? E una riga del 2026-09 lunga 3.000?
2. Che differenza c'è tra `- D-a → D-b` e `- D-a → D-b (in part)` per `--file` e per l'hook?
3. Al primo tocco di un file con 10 lezioni e 10 decisioni, quante voci porta l'hook e in che ordine di tipo?
4. Perché non si usa una data come confine della "riga nuova"?
5. Quali commit sono locali, e chi decide il push?
