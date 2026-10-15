# HANDOFF — Family, fase 3 chiusa: gate delle righe nuove, rigioco, tetto a 60 — 2026-10-15

Origine: Claude Code (sessione a43cd04b, `/home/dietpi/dev/Family-public`, `main`) · Destinazione prevista: Claude Code, stessa cartella

## Obiettivo
La fase 3 del brief `/home/dietpi/dev/varie/briefs/family-decisions-index.md` è **chiusa**: lettore delle decisioni, registro delle
sostituzioni, hook, gate delle righe nuove, rigioco e rapporto ad Alberto. La sessione successiva non ha un compito ereditato da
questa: chiede ad Alberto il prossimo lavoro e intanto rispetta il gate nuovo quando scrive in `docs/DECISIONS.md`.

## Contesto indispensabile
**Il gate su ogni riga nuova di `docs/DECISIONS.md`** (`tools/decisions.py --check`, lanciato dall'harness, commit `34986c2`).
Ci scrivi tu: le regole valgono per le tue righe.
- **Riga nuova:** ogni riga sotto `D-2026-10-15-890482` (costante `GATE_AFTER`). Le righe sopra non si misurano.
- **Lunghezza:** al massimo 1.000 caratteri, contati sulla riga intera così com'è nel file, barre comprese.
  - Fino al 2026-11-15 compreso una riga più lunga dà `decisions: warning: …`, che il pre-commit stampa dopo il conteggio.
  - **Dal 2026-11-16 è un errore**, anche per le righe scritte prima di quella data e sotto il confine.
  - Il resto del perché va nel messaggio di commit.
- **Parole di revisione:**
  - **La regex è `REVISES` in `tools/decisions.py`.** Comprende le formule esplicite ("row above", "the AAAA-MM-GG row", "supersed", "replaces the", "corrects the", "correction:") e in più retract*, withdraw[sn], amends, reverses, reversal, corrects, corrected.
  - **Cosa deve fare la riga:** una riga che le contiene deve nominare un id `D-…` esistente, oppure contenere la frase letterale `no row replaced`.
  - **Attenzione:** "supersed" prende anche il nome file `DECISIONS-SUPERSEDED.md`, quindi una riga che lo cita deve nominare un id.
- **Sostituzioni:** se la riga sostituisce o emenda una decisione, la coppia va in `docs/DECISIONS-SUPERSEDED.md` **nello stesso commit**, scritta a mano. Il gate non lo controlla.
  - **Formato:** `- D-vecchia → D-nuova`, oppure con ` (in part)` in fondo, e la riga del motivo indentata sotto.
- **Id di una riga:** `D-<data>-` più i primi 6 hex dello SHA-1 del testo della riga. Si calcola con `python3 tools/decisions.py --grep '<parole>'`.

**Hook `tools/lesson-hook.py`:**
- `FILE_CAP = 5` per file: lezione e decisione a turno, partendo da una lezione.
- `SESSION_CAP = 60` per sessione, lezioni e decisioni insieme (commit `5b24c5f`, era 30).
- Latenza mediana 42,4 ms su 15 esecuzioni, rimisurata oggi.

**Numeri del rapporto ad Alberto (prova 4, già consegnato in chat):**
- **Candidate e sostituzioni:** 70 candidate esaminate. Le coppie oggi sono 52: 21 sostituzioni piene e 31 emendamenti, secondo `--check` dopo `5b24c5f`.
- **Recupero del passato:** circa 25k token, cioè 75.923 byte letti.
- **Rigioco su 25 transcript** (escluso a43cd04b):
  - **Tetto 30:** mediana 4.276 caratteri e massimo 4.930 per sessione. Il tetto scattava in 18 sessioni, tra l'evento 23 e l'88.
  - **Tetto 60:** mediana 8.500 e massimo 9.520. Il tetto scatta ancora in 12 sessioni.
  - **Senza tetto:** massimo 99.174.
  - **In token:** circa 3k token per sessione con il tetto a 60, al rapporto di ~3,04 byte/token del brief.

## Decisioni prese (e perché)
- **Confine della "riga nuova" = id `GATE_AFTER`, non una data** → le date tornano indietro nei merge. Un registro senza quella riga è rifiutato, così un confine perso non lascia passare tutto in silenzio. *(D-2026-10-15, righe di implementazione)*
- **Lunghezza misurata sulla riga intera** e data iniettabile con `FAMILY_DECISIONS_TODAY` → nei check la data è fissata, mentre il gate sull'albero legge l'orologio vero perché è il gate stesso.
- **Regex di revisione stretta** (127 righe trovate, tutte le 47 righe di revisione registrate) invece di quella ampia (214 righe, 45 di quelle 47).
- **Il gate non pretende la coppia in SUPERSEDED** → 20 candidate su 70 citano una riga senza cambiarla. Esiste la via d'uscita `no row replaced` per chi ritratta qualcosa che non è una riga (es. `D-2026-09-22-812067`).
- **Il pre-commit stampa gli avvisi del gate** → un harness verde non mostrava nient'altro.
- **`SESSION_CAP` = 60** → l'ha deciso Alberto sui numeri del rigioco. È la riga `D-2026-10-15-31355b`, che emenda in parte `D-2026-10-15-890482`, e chiude la voce 110 di `docs/BACKLOG.md`.

## Strade scartate (e perché)
- **Regex ampia di revisione** ("no longer", "replaced", "override"…) → quasi il doppio delle righe e una recall peggiore.
- **Cercare le parole di revisione nella sola cella Decision** → trova 30 sole delle 47 righe di revisione.
- **Tetto 30** → tace dopo i primi 23–88 eventi.
- **Nessun tetto** → fino a 99k caratteri nella sessione più lunga.
- **Una variabile d'ambiente per spostare il confine nei test** → avrebbe testato un valore diverso da quello vero. I check accodano le righe di prova al registro reale.

## Stato
**FATTO** (tutto su `origin/main`, push fino a `5b24c5f`)
- **`34986c2`, gate delle righe nuove:**
  - 7 check nuovi nella sezione "the decisions register…", che ora ne ha 23;
  - 8 mutazioni `decisions-gate-*.mut`, tutte prese;
  - avvisi nel pre-commit;
  - 3 righe DECISIONS.
- **`19e769d`:** voce 110 di BACKLOG, il tetto speso nei primi minuti.
- **`5b24c5f`, tetto 60:**
  - check "and the cap a session has when nothing lowers it is sixty";
  - mutazione `lesson-hook-session-cap-back-to-thirty.mut`, presa;
  - riga DECISIONS e coppia in SUPERSEDED.
- **Gate:** pre-commit a 4.291 check passati; `mutate.py --changed` 91 su 91.

**IN CORSO**
- Niente. L'albero è pulito salvo `addons/Family.zip`, che non è tracciato e non è nostro. Il commit di questo handoff è locale.

**BACKLOG**
1. Chiedere ad Alberto il prossimo lavoro.
2. Verso il 2026-11-15, guardare se il pre-commit stampa avvisi di lunghezza: dal 16 diventano errori e bloccano ogni commit finché la riga resta, e DECISIONS è append-only.
   - Se ne compaiono, chiedere ad Alberto prima di quella data.
   - Una correzione andrebbe scritta come riga nuova; la riga lunga però resterebbe nel file.

## Artefatti
| Artefatto | Dove | Stato | Leggibile? |
|---|---|---|---|
| Brief fase 3 | `/home/dietpi/dev/varie/briefs/family-decisions-index.md` | chiuso | sì |
| Gate e lettore | `tools/decisions.py` | finale | sì |
| Hook | `tools/lesson-hook.py` | finale | sì |
| Script di rigioco | `/tmp/claude-1000/-home-dietpi-dev-Family-public/a43cd04b-72aa-4de8-bc62-5852edad2fb4/scratchpad/replay.py` | temporaneo | forse NO: rilegge ogni transcript `.jsonl` (prompt e chiamate Edit/Write/NotebookEdit/Bash) e passa ogni evento ad `answer()` del modulo hook importato in-process, con `FAMILY_LESSON_STATE` nello scratchpad e lo stato azzerato per sessione; ~2 minuti per giro |
| Script di latenza | stesso scratchpad, `latency.py` | temporaneo | forse NO: 15 `subprocess.run` dell'hook con un evento Edit su `tests/Harness.lua` e un session_id nuovo a ogni giro |

## Regole di lavoro concordate
- **Lingua:** con Alberto si parla italiano; repo, codice e commit sono in inglese. Lo stile di output è conciso.
- **File:** si dichiarano per nome prima di toccarli. Un file fuori lista è uno stop, oppure va detto esplicitamente nel rapporto.
- **DECISIONS** è append-only e una decisione si scrive nello stesso turno in cui si prende. Ora valgono anche le regole del gate qui sopra.
- **Prima di ogni commit:**
  - l'harness del pre-commit;
  - `python3 tools/mutate.py --changed`;
  - i `.mut` nuovi non tracciati vanno lanciati con `python3 tools/mutate.py --all <file>`.
- **Gate:** in primo piano, output in un file dello scratchpad, mai una pipe tra il gate e il suo exit status. Stage per nome di file. Mai squash.
- **Numeri:** mai citarli a memoria (L-115).
- **Mutazioni:** indeboliscono la regola, non l'istanza (L-030), e vanno viste fallire.
- **Rischi:** un rischio nominato va scritto subito, come check o voce di BACKLOG (L-091), mai lasciato solo in chat.
- **Domande ad Alberto:** opzioni numerate con una raccomandazione e i numeri di ciascuna.
- **Riservati, da chiedere:** push, tag `v*`, cancellazioni, riscrittura della storia, licenze e dipendenze, righe `allow`. Il push di oggi l'ha autorizzato Alberto esplicitamente.
- **Da non toccare:** `addons/Family.zip` e `/mnt/RemoteBU1`.

## Problemi aperti / dubbi
- La regex di revisione prende anche il nome `DECISIONS-SUPERSEDED.md`. È innocuo finché quelle righe nominano un id, ma potrebbe sorprendere qualcuno.
- `D-2026-09-22-812067` resta senza coppia, perché ritratta qualcosa che non è una riga.
- Family-retail (branch `forever`) riceve `.claude/settings.json` solo dopo il merge di `main`; lo decide la sessione FAMILY FOREVER, non noi.
- Il commit di questo handoff non è pubblicato: il push è di Alberto.

## PROSSIMA AZIONE
Chiedere ad Alberto quale lavoro segue la fase 3. Non c'è un compito ereditato da eseguire.

## Verifica
Rispondendo solo con questo file, la sessione ricevente deve saper dire:
1. Scrivi oggi una riga DECISIONS di 1.100 caratteri: cosa succede adesso e cosa al primo commit del 2026-11-16?
2. Una riga nuova dice "This corrects the count in `D-2026-10-15-31355b`": passa il gate? E se l'id fosse inventato?
3. Come si scrive una riga che ritratta un'affermazione mai finita in DECISIONS?
4. Quante voci al massimo porta l'hook in una sessione, e perché non 30?
5. Quali commit di questa sessione sono pubblicati?
