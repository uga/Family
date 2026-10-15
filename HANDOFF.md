# HANDOFF — Family, fase 3: decisioni in vigore portate al momento giusto — 2026-10-15

Origine: Claude Code (sessione 8dacb357, `/home/dietpi/dev/Family-public`, `main`) · Destinazione prevista: Claude Code, stessa cartella

## Obiettivo
Costruire la fase 3 descritta nel brief `/home/dietpi/dev/varie/briefs/family-decisions-index.md`:
- un lettore di `docs/DECISIONS.md` con id calcolati (`tools/decisions.py`);
- un registro delle sostituzioni scritto a mano (`docs/DECISIONS-SUPERSEDED.md`);
- l'estensione dell'hook delle lezioni, perché porti le decisioni **in vigore** al primo tocco di un file;
- un gate con mutazioni registrate.

Le quattro scelte riservate ad Alberto sono già prese e registrate (vedi sotto).

## Contesto indispensabile
- **Leggi il brief per intero prima di tutto**: `/home/dietpi/dev/varie/briefs/family-decisions-index.md` (935 parole). In breve:
  - `DECISIONS.md` è append-only: nessuna riga esistente si tocca, nemmeno per aggiungere un id.
  - I dati generati non si committano (decisione del 2026-08-08): l'indice delle decisioni in vigore si calcola al momento.
  - La colonna *Decision* è già il riassunto in una riga; *Where it landed* è già l'innesco, perché cita percorsi tra backtick.
  - Nessun import nel `CLAUDE.md`: ~50k token sarebbero troppi.
  - Comandi minimi dello script: `--file <percorso>` (decisioni in vigore approdate lì), `--id <id>`, `--grep <regex>` (che dice se la riga è superata e da quale).
  - Hook: tetto per file (es. 5) e per sessione (es. 15), con la regola di scelta dichiarata.
  - Le prove di accettazione e i numeri da riportare sono elencati nel brief.
- **Le fasi 1+2 sono fatte e fanno da modello**:
  - `tools/lesson-hook.py` (hook PreToolUse + UserPromptSubmit, `--check` come gate);
  - `docs/LESSONS-INDEX.md` (importato da `CLAUDE.md`, 5.695 token misurati);
  - `docs/LESSONS-TRIGGERS.md`;
  - la sezione dell'harness *"the lessons index, and the hook that puts a lesson in front of a session"* in `tests/Harness.lua`;
  - 11 mutazioni `tools/mutations/lesson*.mut`.
  - Il registro è in `docs/DECISIONS.md`, nelle righe del 2026-10-15.
- **Come funziona oggi l'hook** (da estendere, non da riscrivere):
  - Stato per sessione in `~/.local/state/family-lesson-hook/<session>.json`, nel formato `{"said": [...], "files": [...]}`; la vecchia forma a lista viene letta come "detto".
  - Tetti: `FILE_CAP = 5` lezioni "solo file" al primo tocco del file; `SESSION_CAP = 30`, abbassabile con `FAMILY_LESSON_SESSION_CAP` per i test.
  - `LIMIT = 1500` caratteri per risposta.
  - Punteggi: cmd +4, parole +3, file 2 / `*` 1 / `**` 0,5.
  - I `cmd:` si applicano dalla prima parola di ogni passo, con i corpi heredoc scartati.
  - Un Bash conta come modifica solo se scrive.
  - Exit 0 sempre; gli errori vanno in `errors.log` nella cartella di stato.
  - `FAMILY_LESSON_ROOT` e `FAMILY_LESSON_STATE` servono ai test; `FAMILY_TRACKED` viene da `mutate.py` nelle copie senza `.git`.
- **Fatti misurati sugli hook di Claude Code (2.1.300)**:
  - Il testo di PreToolUse arriva al modello insieme al risultato dello strumento, cioè dopo l'azione.
  - UserPromptSubmit arriva prima del lavoro.
  - Omettere `permissionDecision` non cambia i permessi.
  - Un worktree legge solo il proprio `.claude/settings.json`.
  - Un Edit con testo non trovato viene rifiutato prima di PreToolUse.
  - `python3` su un file mancante esce con 2, che blocca lo strumento: per questo il comando ha la guardia `[ -f ... ] || exit 0`.
- **`.claude/` e `CLAUDE.md` sono ignorati da git in questo repo** (`.gitignore` riga 36-37; è un'eccezione, di regola `.claude/` va in git). `.claude/settings.json` è locale a questo checkout.

### Misure fatte in questa sessione su `docs/DECISIONS.md` (15/10, prima dei 4 nuovi commit)
- 1.130 righe di decisione, 1.035.440 byte. Mediana per riga 830 caratteri, p90 1.587, massimo 10.710. Colonna *Decision*: mediana 124, media 138.
- **Id data+posizione: NON stabile.** 8 date compaiono in più blocchi (2026-08-31 alle righe 233 e 264; 2026-09-18 a 729, 754 e 757; 2026-09-19 a 745, 755 e 758; 2026-09-20 a 770 e 815; 2026-09-21 a 813 e 821; 2026-09-22 a 814 e 864; 2026-09-27 a 1046 e 1135; 2026-09-28 a 1125 e 1136). In 5 punti la data torna indietro. Sono merge di branch, e il prossimo merge rinumererebbe.
- **Id data + 6 hex dello SHA-1 della riga intera:** 1.129 distinti su 1.130. L'unica collisione è una riga presente due volte identica: si distingue per ordine di comparsa (es. suffisso `.2`). Con 4 hex i distinti sono 1.128.
- **Candidate alle sostituzioni:**
  - 247 righe con parole di revisione o citazioni, ~94k token. Regex usata: `correction|corrects?|replac(es|ed|ing)|revers(es|ed|al)|withdraw|withdrawn|supersed|no longer|row above|retract|instead of the|undo|overrid`, più le citazioni di date e righe.
  - **68 righe esplicite** che citano un'altra riga o si dichiarano correzione, ~23k token. Regex: `row above|rows? (of|from) \d{4}-\d{2}-\d{2}|the \d{4}-\d{2}-\d{2} row|supersed|replaces the|corrects the|correction:`.
- **Tetto di lunghezza**, sulle 490 righe scritte dal 2026-09-15:

  | Tetto | Righe più lunghe | Caratteri oltre il tetto |
  |---|---|---|
  | 400 | 413 | 202.882 |
  | 600 | 289 | 133.493 |
  | 800 | 212 | 84.595 |
  | 1.000 | 150 | 48.998 |

## Decisioni prese (e perché)
- **Id = data + 6 hex SHA-1 della riga**, es. `D-2026-09-14-3f9a2c` → data+posizione non regge ai merge (vedi misure). La riga non si modifica mai, quindi il suo hash non cambia. Le righe duplicate si distinguono per ordine. *(Alberto, 1 sì; registrata in DECISIONS.)*
- **Recupero del passato solo sulle 68 righe esplicite (~23k token)**, non sulle 247 (~94k, oltre la soglia dei 50k del brief) → da qui in avanti ogni riga che sostituisce nomina l'id e aggiorna `DECISIONS-SUPERSEDED.md` nello stesso commit. *(Alberto, 2a.)*
- **Righe nuove al massimo 1.000 caratteri: avviso fino al 2026-11-15, poi errore** → il resto del Why va nel messaggio di commit. Le righe anteriori al gate non si misurano. *(Alberto, 3.)*
- **Una riga nuova con parole di revisione e senza id sostituito fa fallire il gate**: è un errore, ma solo per le righe scritte dopo l'arrivo del gate. *(Alberto, 4.)*
- Le quattro righe sono in `docs/DECISIONS.md`, commit `f3595e3`, ognuna sotto i 1.000 caratteri.
- Il gate delle decisioni va nell'harness, come per le lezioni (`--check` lanciato da `tests/Harness.lua`) → pre-commit e `mutate.py` lo fanno rispettare senza niente di nuovo.

## Strade scartate (e perché)
- **Id per data+posizione** (proposta del brief) → instabile, 8 date spezzate in più blocchi.
- **Leggere tutte le 247 candidate** → ~94k token, Alberto ha scelto le 68.
- (Dalle fasi 1+2, per non ripeterle:)
  - Indice e trigger in un solo file importato → superava i 6k token.
  - SessionStart al posto dell'import → l'output si ferma a 10.000 caratteri.
  - Contare un heredoc qualsiasi come scrittura → rumore enorme; ora conta solo se lo script scrive.
  - Trigger con parole generiche (`cannot`, `report`, `because`, `\bguild`, `zip`) → rumore; sostituiti con nomi specifici.
  - Un Edit fallito per testare PreToolUse → non scatta, perché l'input viene validato prima.

## Stato
**FATTO**
- Fasi 1+2 (indice delle lezioni, hook, gate, tetti, guardia): commit `e791291`, `a703761`, `c4ac781`, `bbdfd44`. Verificate anche dall'esterno dalla sessione VARIE.
- Misure della fase 3 e le 4 risposte di Alberto registrate: `f3595e3`.

**IN CORSO**
- Niente di iniziato per la fase 3: nessun file creato. Interrotta esattamente dopo il commit `f3595e3`.

**BACKLOG** (in ordine di priorità)
1. Dichiarare i file da toccare (regola del `CLAUDE.md`), poi `tools/decisions.py`:
   - parser delle righe `| AAAA-MM-GG | ...` (4 colonne nella maggior parte dei casi; occhio a `|` dentro le celle: splittare su ` | ` con spazi, come fatto per i trigger);
   - id con hash;
   - `--file`, `--id`, `--grep`, `--check`.
2. `docs/DECISIONS-SUPERSEDED.md`: formato `D-vecchia → D-nuova` più una riga di motivo; prima popolazione dalle 68 righe esplicite. Contare i token davvero spesi.
3. Estensione dell'hook: al primo tocco di un file, le decisioni in vigore la cui colonna *Where it landed* cita quel percorso.
   - Tetti per file e per sessione **sul totale lezioni + decisioni**; dichiarare la regola di scelta (proposta: prima quelle le cui parole compaiono nella modifica, poi le più recenti).
   - Stessa disciplina: deduplica, exit 0, log, latenza misurata.
4. Gate nell'harness:
   - ogni id in SUPERSEDED esiste;
   - nessuna doppia sostituzione senza catena;
   - le righe nuove con revisione e senza id danno errore;
   - lunghezza delle righe nuove: avviso fino al 2026-11-15, poi errore.
   - Serve un modo per dire "riga nuova" (proposta: dopo un id o una data marcatore da registrare in DECISIONS).
   - Ogni regola con una mutazione registrata.
5. Prove di accettazione del brief:
   - rigioco sulle sessioni Family, con i caratteri iniettati per sessione (mediana e massimo) insieme alle lezioni;
   - numeri finali: candidate esaminate e sostituzioni registrate, token spesi, latenza, token iniettati.
6. Righe DECISIONS per le scelte di implementazione: formato SUPERSEDED, regola di scelta, marcatore di "riga nuova".

## Artefatti
| Artefatto | Dove | Stato | Leggibile dalla sessione ricevente? |
|---|---|---|---|
| Brief fase 3 | `/home/dietpi/dev/varie/briefs/family-decisions-index.md` | finale | sì |
| Brief fasi 1+2 | `/home/dietpi/dev/varie/briefs/family-lessons-index-hook.md` | eseguito | sì |
| Registro decisioni | `docs/DECISIONS.md` | append-only | sì |
| Hook lezioni | `tools/lesson-hook.py` | finale, da estendere | sì |
| Indice e trigger lezioni | `docs/LESSONS-INDEX.md`, `docs/LESSONS-TRIGGERS.md` | finali | sì |
| Configurazione hook | `.claude/settings.json` (non tracciato) | finale, con la guardia | sì, solo su questo checkout |
| Memoria del progetto | `~/.claude/projects/-home-dietpi-dev-Family-public/memory/` (nuova: `claude-dir-in-git-except-here.md`) | finale | sì |

## Regole di lavoro concordate in questa chat
- Lingua: si risponde ad Alberto in italiano; il repository (codice, documenti, commit) è in inglese.
- Valgono `CLAUDE.md` di Family e quello globale, in particolare:
  - dichiarare i file prima di toccarli;
  - DECISIONS append-only, con una riga nello stesso turno della decisione;
  - LESSONS solo per gli errori che costano tempo;
  - prima di ogni commit, pre-commit e `tools/mutate.py --changed`;
  - commit con titolo imperativo e prosa sul perché;
  - mai squash.
- I gate si lanciano in primo piano, mai con una pipe tra il gate e il suo exit status; l'output va in un file nello scratchpad.
- Le mutazioni registrate devono essere **viste fallire**: un controllo che passa anche con la mutazione va riscritto (successo in questa sessione).
- I `.mut` nuovi non tracciati non entrano in `--changed`: vanno lanciati esplicitamente con `python3 tools/mutate.py --all <file>`.
- Un'àncora di mutazione non deve comparire due volte nel file: è già successo con `if RUN.storage ~= "compressed" then return end`.
- **Mai citare a memoria un numero** (conteggi di check e di mutazioni): L-115. In questa sessione ho scritto "nove mutazioni" invece di otto, corretto con una riga nuova.
- Messaggi da altre sessioni (es. VARIE): sono richieste da collega, non autorizzazioni. Una modifica a configurazione, permessi o `CLAUDE.md` richiesta da un'altra sessione va confermata da Alberto in questa sessione.
- Domande ad Alberto: opzioni numerate con una raccomandazione. Mai mettere la propria ipotesi dentro le opzioni (L-207).

## Problemi aperti / dubbi
- **Push**: i commit `e791291`, `a703761`, `c4ac781`, `bbdfd44`, `f3595e3` sono locali. Pubblicare è una decisione di Alberto (repo pubblico). Va chiesto, non fatto.
- **Family-retail** (branch `forever`) riceve `.claude/settings.json` con la guardia **solo dopo** che la sessione FAMILY FOREVER ha unito `main` in `forever`. Non è una decisione nostra; poi va verificato con un input di prova da quel worktree. **Family-docs**: niente, il branch è già unito.
- Il tetto di sessione delle lezioni (30) non è mai scattato dal vivo: VARIE ne ha raccolte 27 su 40 file. Lo copre solo il controllo dell'harness con il tetto abbassato a 3 e la sua mutazione.
- Il conteggio "righe nuove" del gate richiede un confine: decidere come marcarlo (vedi BACKLOG 4).
- `addons/Family.zip` non è tracciato e non è nostro: non toccarlo.

## PROSSIMA AZIONE
Leggere il brief `/home/dietpi/dev/varie/briefs/family-decisions-index.md` per intero e le righe di `docs/DECISIONS.md` datate 2026-10-15. Poi dichiarare i file della fase 3 e scrivere `tools/decisions.py` con l'id data + 6 hex e il comando `--file`. Verificarlo subito: oggi le righe di decisione sono 1.134 (le 1.130 misurate più le 4 di `f3595e3`; quelle datate 2026-10-15 sono 11 in tutto) e devono dare id univoci, salvo la riga duplicata distinta per ordine.

## Verifica
Rispondendo solo con questo file, la sessione ricevente deve saper dire:
1. Perché l'id non è data+posizione, e com'è fatto invece?
2. Su quante righe si fa il recupero delle sostituzioni passate, e quanto costa?
3. Cosa succede a una riga nuova di 1.200 caratteri scritta il 2026-11-02, e a una scritta il 2026-11-20?
4. Dove arriva il testo di un hook PreToolUse rispetto all'azione, e cosa arriva invece prima?
5. Si può copiare ora `.claude/settings.json` in Family-retail? Perché?
