# Area admin SommoMemory

L’interfaccia è servita dal backend su **`/admin`**, separata dal client Flutter.
Le API `/admin/api/*` richiedono una sessione admin ottenuta con una passkey;
i token dei giocatori e il codice di attivazione non consentono di leggere i dati.
La dashboard è di sola consultazione per profili, lobby e partite.

## Stato della produzione

Pubblicata il **5 novembre 2026** su **https://sommomemory.sommomi.cc/admin**,
release **20261105T213905Z-admin**, derivata dalla versione online
**20261105T194451Z-privacy**. Il rilascio integra solo l’admin e la relativa
rilevazione operativa nella versione attuale del servizio. Il gioco web, i login
Apple/Google e la configurazione privata sono preservati. Le nuove arene e
classificate presenti nei sorgenti locali non fanno parte di questa pubblicazione:
la dashboard le mostrerà quando saranno attive nel servizio; nel frattempo le
arene sono indicate come non disponibili e le corone non presenti mostrano “—”.

Backup SQLite coerente verificato prima del rilascio; profili, sessioni, registro
e collegamenti account preesistenti preservati. Verificati 65 test del pacchetto
di rilascio e l’accesso pubblico da desktop e telefono, fermandosi prima della
registrazione personale della passkey. Il codice monouso di produzione è stato
generato e conservato privatamente fuori dalla repository, senza inserirlo nelle
ricevute. [Ricevuta del rilascio](../artifacts/admin/production-deploy.json).

## Cosa mostra

- Utenti attivi nelle ultime 24 ore, 7 e 30 giorni, deduplicati per profilo.
- Giocatori connessi alle stanze, connessioni WebSocket totali, partite in corso e lobby.
- Profili totali, nuovi profili, profili con account o recupero attivo.
- Grafico giornaliero UTC di attività e partite online iniziate, con filtri 24 ore / 7 / 30 / 90 giorni.
- Partite iniziate, terminate, completate e perse per abbandono; durata media quando entrambi gli orari sono noti.
- Partite per arena, gemme effettivamente accreditate come premio, sblocchi e premi online in attesa.
- Lobby con posti occupati, presenza e stato “Pronto”; partite live con modalità e round.
- Storico online paginato, ricerca per codice/nickname corrente, modalità e stato; CSV della pagina filtrata.
- Ultimi 50 profili, ricerca per nickname/ID, ultima attività rilevata, gemme, corone e numero di account collegati.
- Gestione delle passkey: aggiunta e rimozione, senza consentire di rimuovere l’ultima.

L’aggiornamento automatico avviene ogni 15 secondi quando la pagina è visibile.
Errori di caricamento lasciano visibili i dati precedenti accompagnati da un avviso.
La dashboard non usa servizi esterni, font remoti, cookie di analisi o archiviazione delle credenziali nel browser.

## Significato e limiti dei dati

Un profilo è attivo quando una credenziale valida contatta il servizio, quando
viene emessa una credenziale per quel profilo o quando compie un’azione online.
I contatti ripetuti vengono accorpati per minuto e giorno UTC; il conteggio
all’estremo della finestra mobile può quindi differire di meno di un minuto.
Più dispositivi con lo stesso profilo contano come un utente. I giocatori senza
profilo sono visibili nelle stanze live, ma non aggiunti ai conteggi storici degli utenti.

La rilevazione parte dall’attivazione di questa versione: **non vengono inventati
utenti, date o partite precedenti**. Le stanze presenti vengono importate come
osservazioni; gli orari di inizio/fine non disponibili restano nulli. Le classifiche
da tre round contano come una partita, le rivincite come partite distinte e le lobby
mai iniziate non entrano nello storico. Una stanza scomparsa prima dell’esito è
“Non disponibile”, non una partita completata. Il grafico non traccia zeri nei
giorni precedenti all’attivazione.

Lo storico elenca le partite osservate nel periodo; i riepiloghi di inizio e fine
usano invece i rispettivi orari effettivi. Non ricostruisce le partite locali o
Bluetooth dai soli premi. Le gemme assegnate comprendono anche premi locali e
Bluetooth validati; i bonus iniziali sono esclusi. Gli sblocchi sono le transazioni
con spesa di gemme. Nessun dato rappresenta ricavi o acquisti con denaro reale.

Attività e storico online sono conservati per **90 giorni**. L’eliminazione del
profilo cancella l’attività e scollega il profilo dallo storico; i nomi dello
storico vengono letti dal profilo corrente, non copiati nel registro. Non vengono
archiviati nello storico nomi degli ospiti senza profilo, tabelloni, mosse,
indirizzi IP, email, token, codici di recupero o credenziali dei provider.
Le stanze vive continuano a seguire la scadenza già prevista dal gioco.

## Prima attivazione in produzione

`ADMIN_ORIGIN` deve coincidere esattamente con l’origine HTTPS dell’admin.
Il valore predefinito è `https://sommomemory.sommomi.cc`; l’RP ID della passkey è
il relativo hostname, senza ampliarlo al dominio padre. Non serve modificare
le app Android/iOS o aggiungere un servizio separato.

Alla prima partenza senza passkey il servizio genera, con permessi `0600`,
`DATA_DIR/admin-enrollment.json`. Il codice scade dopo 24 ore e non viene stampato,
restituito dalle API o inserito nelle risposte HTML. Leggerlo tramite accesso
amministrativo al volume privato, aprire `/admin`, inserire il codice e premere
**Crea passkey**. Il browser richiede Touch ID, Face ID, PIN del dispositivo o
il gestore di credenziali. La chiave privata nasce nel dispositivo/gestore:
**il server e Codex non possono generarne una al suo posto**.

Il codice non è una password per entrare nella dashboard. Una registrazione
WebAuthn verificata lo consuma e apre una sessione; i successivi accessi usano
esclusivamente la passkey. Il bootstrap iniziale non funziona più se esistono
passkey, anche se si ripristina una vecchia copia del file. Il database conserva
anche l’impronta dei codici consumati, così nemmeno un codice di recupero già usato
può essere riutilizzato ripristinando soltanto il file di attivazione.

Per rinnovare un codice scaduto, eseguire come utente del servizio (con il volume
corretto montato), salvando il risultato **fuori dalla repository**:

```sh
node scripts/admin-enroll.mjs \
  --data-dir=/percorso/privato/dati \
  --output=/percorso/privato/admin-activation.txt
```

Questo codice dura 30 minuti. Il file di output viene creato in modo esclusivo
con permessi `0600`: usare un nuovo nome se esiste già. Non condividere o committare
il codice. Eliminarne la copia locale dopo l’attivazione.

## Sviluppo locale

Le passkey di localhost e quelle del dominio pubblico sono distinte. HTTP è
consentito solo su loopback. Impostare un’origine fissa, compresa la porta:

```sh
cd server
ADMIN_ORIGIN=http://localhost:8790 PORT=8790 npm start
```

Aprire `http://localhost:8790/admin` e registrare una passkey usando il codice
nel file privato `server/data/admin-enrollment.json`. Non alternare `localhost`
e `127.0.0.1`: rappresentano origini e passkey differenti.

## Sessioni, chiavi di riserva e recupero

Le sessioni durano al massimo 8 ore e sono conservate sul server soltanto come
impronte SHA-256, in un cookie `HttpOnly; Secure; SameSite=Strict` con prefisso
`__Host-` in produzione. Su localhost il cookie non ha `Secure` né il prefisso.
Le richieste di modifica richiedono l’Origin esatto; nessuna origine CORS è ammessa.
Le challenge sono monouso, legate a un cookie separato e scadono dopo 5 minuti.
Registrazione e accesso richiedono presenza e verifica dell’utente, RP ID,
challenge, origine, firma e contatore dell’autenticatore.

Aggiungere una chiave di riserva dalla sezione **Accesso**. Dopo 5 minuti
dall’accesso occorre accedere nuovamente per gestire le chiavi. La rimozione
revoca tutte le sessioni di quella passkey. Uscire elimina la sessione corrente;
il browser svuota anche i dati della dashboard. Sono ammesse al massimo 10
passkey e 32 sessioni contemporanee. Le API applicano limiti per indirizzo e
non registrano l’IP nel database dell’admin.

Se tutte le passkey sono perse, l’operatore con accesso al volume privato può
eseguire lo stesso comando di attivazione con **`--recover`**. La nuova
registrazione invalida tutte le sessioni admin precedenti. Le vecchie passkey
restano elencate e possono essere rimosse dopo il recupero. Non basta aggiungere
un parametro nel browser: il recupero deve essere autorizzato nel file privato
creato sul server. Tenere i permessi del volume e dei backup riservati.

## Distribuzione e verifica

Distribuire il backend e `server/public/admin.*`, le dipendenze bloccate e
l’informativa privacy aggiornata con il normale flusso documentato in
`deploy/README.md`. La route `/admin` è già coperta dal proxy esistente.
Non è necessario ricompilare Flutter per questa funzionalità.

Le migrazioni SQLite sono additive e i dati restano nel volume `mymemory-data`.
Le passkey pubbliche, le sessioni, l’attività e lo storico fanno parte di
`economy.sqlite`: effettuare un backup SQLite coerente con la procedura già
prevista. Non ripristinare vecchi backup in produzione senza considerare le
sessioni revocate e le cancellazioni successive.

```sh
cd server
npm ci
npm test
```

I test admin usano firme ES256 e attestazioni WebAuthn reali generate da un
autenticatore software di test: verificano origine/RP ID, verifica utente,
firma alterata, replay, contatori, bootstrap, sessioni, gestione delle chiavi,
anonimizzazione, rivincite e conservazione. Le schermate in `artifacts/admin/`
sono anteprime ottenute in un database temporaneo con **dati di collaudo**,
non statistiche di produzione.

L’implementazione WebAuthn usa [SimpleWebAuthn](https://simplewebauthn.dev/docs/packages/server)
con versioni bloccate nel lockfile; il browser carica la libreria dallo stesso servizio.
