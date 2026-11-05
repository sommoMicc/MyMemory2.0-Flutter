# SommoMemory — Specifica arene, corone e partite

Versione 3 — 5 novembre 2026. Fonte: decisioni concordate nella chat di progetto
e richiesta successiva di completare l'implementazione.

## 1. Scopo e stato

Introdurre una progressione competitiva per arene. Un'arena contiene più deck
collegati da un tema; un deck contiene 18 soggetti, ciascuno ripetuto due volte
nel tabellone quando viene selezionato. Le corone misurano la posizione
competitiva; le gemme comprano deck aggiuntivi.

L'implementazione comprende le quattro arene complete, il negozio, il catalogo
offline e le classificate a invito da tre round. Il matchmaking automatico e gli
acquisti in denaro restano sviluppi futuri. Le modalità esistenti e i progressi
dei profili vengono conservati. La sezione 6 fissa le scelte operative adottate
per completare i dettagli che erano rimasti aperti nella prima versione.

## 2. Regole concordate

### Risorse e progressione

- Corone iniziali: 0; saldo minimo: 0.
- Vittoria classificata: +20 corone. Sconfitta: −20, limitata dal minimo 0.
  Pareggio: nessuna variazione. Valori iniziali soggetti a futuro bilanciamento.
- Una sola variazione per profilo e per partita completa, non per round.
- La classificata usa l'arena corrispondente alle corone attuali. Il giocatore
  non sceglie liberamente un'arena competitiva inferiore o superiore.
- Raggiungere una soglia sblocca permanentemente quell'arena per le amichevoli.
- Scendere sotto una soglia cambia l'arena della classificata successiva.
  Una partita già iniziata mantiene arena, deck e regole fino al suo esito.
- Il massimo storico delle corone conserva la progressione delle amichevoli.
- Le gemme non acquistano corone o accesso competitivo alle arene.
- I deck acquistati restano di proprietà del profilo, anche dopo una retrocessione.
  Si usano nelle amichevoli delle arene raggiunte e in classificata quando
  l'arena corrisponde nuovamente alle corone attuali.

### Formati

| Proprietà | Amichevole | Classificata |
| --- | --- | --- |
| Durata | 1 round | 3 round effettivi |
| Arena | Tra quelle raggiunte in passato | Da corone attuali |
| Deck | Scelto da chi crea la sfida tra quelli utilizzabili | Tre deck distinti sorteggiati |
| Corone | Nessuna variazione | +20 / −20 / 0 alla fine |
| Avversario | Sfida organizzata dai giocatori | Stanza a invito; matchmaking automatico futuro |

Le modalità singolo, locale e Bluetooth rimangono attività non classificate.
Sono accessibili dal menu delle modalità, con scelta dell’arena amichevole.

### Lobby prima della partita

I client compatibili entrano in una lobby a due posti per amichevoli e
classificate. La partita inizia quando entrambi, connessi, confermano “Pronto”.
Prima dell’inizio l’ospite può uscire liberando il posto: l’host conserva
il codice e può invitare un altro giocatore. Una disconnessione dell’ospite
riserva il posto per 90 secondi, poi lo libera; uscita o scadenza dell’host
chiudono la lobby. Le conferme si azzerano alla disconnessione o all’uscita
dell’ospite. Nessuno di questi eventi produce corone, gemme o abbandono in
partita. I client precedenti continuano ad avviare le loro stanze al secondo
ingresso; per entrare in una nuova lobby serve la capacità `lobby-v1`.

### Sorteggio dei tre deck

All'inizio della partita classificata, dopo aver identificato entrambi i profili:

1. Fissare l'arena della partita.
2. Costruire l'unione dei deck gratuiti dell'arena e dei deck di quella stessa
   arena posseduti da almeno uno dei due giocatori.
3. Rimuovere i duplicati: possedere entrambi lo stesso deck non ne aumenta il peso.
4. Verificare che entrambi i client sappiano renderizzare i deck del catalogo
   richiesto; le capacità dichiarate dal client non provano il possesso.
5. Sorteggiare uniformemente, senza reinserimento, tre deck distinti e il loro
   ordine. Il server conserva il risultato, senza risorteggio alla riconnessione.
6. Usare un deck per round; entrambi i giocatori vedono lo stesso deck e la
   stessa disposizione di carte su due tabelloni individuali del round.

Ogni arena ha almeno tre deck gratuiti. Un aggiornamento client incompatibile
deve produrre una richiesta di aggiornamento prima dell'ammissione, senza
ridurre silenziosamente il catalogo del sorteggio. Nessun deck di altre arene,
a gemme ma non posseduto da nessuno dei due o con immagini mancanti può entrare nel pool.
Un deck acquistato da un solo giocatore è utilizzabile dall'altro nella partita,
ma non viene aggiunto alla sua proprietà permanente.

Il sorteggio dei deck e il mescolamento del tabellone sono operazioni diverse.
Non inviare mai ai client i valori delle carte ancora coperte.

## 3. Prime quattro arene

La soglia è inclusiva. L'ultima fascia non ha limite superiore.

| ID stabile | Nome | Soglia | Fascia classificata | Deck gratuiti |
| --- | --- | ---: | --- | --- |
| `wild_valley` | Valle Selvaggia | 0 | 0–99 | Animali, Fattoria, Fiori e piante |
| `coral_bay` | Baia Corallina | 100 | 100–299 | Oceano, Spiaggia, Navigazione |
| `grand_city` | Grande Città | 300 | 300–599 | Veicoli, Mestieri, Strumenti musicali |
| `space_frontier` | Frontiera Spaziale | 600 | 600+ | Spazio, Laboratorio, Base spaziale |

| Arena | Deck acquistabili | Prezzi in gemme |
| --- | --- | --- |
| Valle Selvaggia | Insetti; Dinosauri | 200; 300 |
| Baia Corallina | Pirati; Abissi | 300; 400 |
| Grande Città | Cibo; Sport; Viaggi | 200; 300; 400 |
| Frontiera Spaziale | Alieni; Robot | 300; 400 |

I prezzi dei tre deck acquistabili esistenti rimangono invariati. I prezzi
dei nuovi deck sono la configurazione iniziale concordata per il catalogo.
Il catalogo comprende 21 deck illustrati: 12 gratuiti e 9 a gemme, tutti completi.
Le 378 immagini sono incluse nel pacchetto; sei deck conservano ID e ordine
precedenti. Provenienza e riproduzione sono documentate in DECKS.md.

### Identificatori dei deck

Gli ID esistenti e l'ordine delle loro 18 carte non cambiano:
`garden` = Animali, `ocean` = Oceano, `cosmos` = Spazio,
`food` = Cibo, `sports` = Sport, `travel` = Viaggi, `paola` = Paola.

Nuovi ID:

| Arena | Gratuiti nuovi | A gemme nuovi |
| --- | --- | --- |
| Valle Selvaggia | `farm`, `flora` | `insects`, `dinosaurs` |
| Baia Corallina | `beach`, `navigation` | `pirates`, `abyss` |
| Grande Città | `vehicles`, `professions`, `instruments` | — |
| Frontiera Spaziale | `laboratory`, `space_base` | `aliens`, `robots` |

`paola` mantiene ID, sillabe, proprietà e gratuità attuali. Proposta di
collocazione adottata per il completamento: allenamento didattico sempre
accessibile nelle modalità non classificate, esterno al sorteggio classificato.

### Requisiti artistici

- Ogni nuovo deck: 18 soggetti distinti e leggibili, nomi accessibili in italiano,
  copertina, retro e associazione allo scenario dell'arena.
- Evitare il riuso delle stesse immagini in più deck di una stessa arena.
- Nuovi contenuti disponibili offline dopo l'inclusione nell'app, con provenienza
  e licenze documentate; nessuna dipendenza da immagini remote durante il gioco.
- I deck a gemme aggiungono temi, mantenendo le stesse regole, numero di coppie
  e ricompense applicabili agli altri deck.
- `contentReady` nel catalogo è distinto da gratuità, possesso e soglia arena.
  Un nome nel catalogo pianificato non rende automaticamente giocabile un deck.

## 4. Modello e responsabilità

### Catalogo

Fonte dati per questa fase: `server/catalog/arenas.v1.json`.
Il file viene incluso automaticamente nel pacchetto server esistente; uno
script genera i dati Dart utilizzati dai modelli client. Validare la parità
tra configurazione server e dati generati. Non aggiungere deck con asset
mancanti agli elenchi giocabili attuali o a `supportedDecks`.

Il catalogo contiene soglie, ordine delle arene, deck, prezzi e stato dei
contenuti. La classificata viene abilitata solo insieme ai contenuti completi
e al motore dei tre round verificato. `contentReady` continua a distinguere i
contenuti reali da eventuali aggiunte future ancora pianificate.

### Profilo

Campi additivi:

- `crowns`: intero non negativo, inizialmente 0.
- `peakCrowns`: intero non negativo, sempre maggiore o uguale a `crowns`.
- `currentArenaId`: derivato dalle corone attuali.
- `unlockedArenaIds`: derivato dal massimo storico; comprende sempre Valle Selvaggia.
- `legacyDecks`: eccezioni di accesso non classificato per le vecchie collezioni
  gratuite già disponibili prima della migrazione.

Il server è autorevole. Il client può mostrare e memorizzare questi dati ma non
inviare un nuovo saldo come aggiornamento del profilo. Campi mancanti nei
salvataggi/client precedenti assumono 0 per le corone. Ignorare revisioni
obsolete dello stesso profilo; conservare le regole attuali per cambio profilo,
login, ripristino e cancellazione. Nessuna concessione di gemme o reset del
portafoglio durante la migrazione.

La transazione di chiusura classificata aggiorna entrambi i
profili e salvare un risultato unico per `matchId`, atomicamente e una sola volta.
`peakCrowns = max(peakCrowns precedente, crowns dopo l'esito)`.
Una sconfitta a zero registra comunque un esito, anche se il delta effettivo è 0.
La cancellazione o ripetizione di una risposta non deve ricreare un accredito.
Non si espone alcun endpoint che permetta al client di assegnare corone.

### Partita classificata

Separare `matchId` da `roundId`. Ogni partita classificata contiene tre round,
un'arena fissata, l'ordine dei deck e i risultati dei round. Un rematch è una
nuova partita, con nuovo ID e nuovo sorteggio. Riconnessione e riavvio riprendono
il round e la sequenza esistenti. I punteggi e le animazioni del singolo round
non devono anticipare il risultato complessivo.

Il futuro matchmaking usa le corone e rispetta l'arena corrente. La prima
versione non deve far scontrare silenziosamente due fasce diverse. Ricerca,
allargamento della fascia, timeout e gestione della coda saranno una specifica
successiva. Le stanze esistenti restano amichevoli; creare una classificata
richiede una scelta esplicita. I due profili devono essere autenticati, distinti
e nella stessa arena corrente. Un profilo può avere una sola classificata
attiva, comprese attesa iniziale e pausa tra i round.
Il client conserva il posto durante una pausa e propone di riprenderlo prima
di aprire un'altra stanza, evitando di perdere la sessione salvata. Una partita
già terminata torna alla home senza chiedere conferma di un abbandono.

## 5. Compatibilità e rilascio

- Le partite esistenti sono amichevoli a un round; conservano il premio da
  20 gemme e le sessioni già emesse. I profili conservano gemme e acquisti.
- I nuovi profili ricevono i tre deck gratuiti della Valle e Paola. I vecchi
  profili conservano inoltre l'accesso non classificato a Oceano e Spazio già
  gratuiti e a tutti gli acquisti precedenti, anche se l'arena non è raggiunta.
  Questa eccezione non sblocca altri deck della stessa arena e non assegna corone.
  I nuovi acquisti richiedono invece che l'arena sia stata raggiunta.
- Nessuna arena è attivabile in classificata senza tutti e tre i suoi deck
  gratuiti completi e almeno due client compatibili.
- `supportedDecks` ammette il catalogo esteso (limite 64) e descrive solo le
  capacità grafiche. La classificata richiede anche `supportedFeatures` con
  `ranked-v1` e `ranked-attempts-v1`, controllati prima di ammissione o ripristino della seduta.
- Nessuna pubblicazione web, build distribuita o modifica agli store è inclusa
  nell'implementazione locale. Nessun acquisto in denaro.
- Lavorare sulla copia esistente preservando le modifiche locali pregresse.

## 6. Scelte operative per il completamento

Queste impostazioni completano la versione 1, senza introdurre il matchmaking
automatico richiesto per il futuro:

1. **Risultato:** vince chi impiega meno tentativi complessivi nei tre round; totale uguale = pareggio. Un tentativo si conta alla seconda carta scoperta, sia in caso di coppia sia di errore.
   Si giocano tutti e tre i round, anche quando un giocatore ne ha già vinti due.
2. **Tabellone:** 12 coppie per round, estratte tra i 18 soggetti del deck in
   classificata. Difficoltà libera 6/8/12/18 nelle modalità non classificate.
3. **Tabelloni individuali:** i due giocatori affrontano contemporaneamente la stessa disposizione su tabelloni separati, senza turni. Scoperte e posizioni dell’avversario non vengono trasmesse. Il round termina quando entrambi hanno trovato le 12 coppie.
4. **Passaggio di round:** fine animazione dell'ultima coppia, risultato del round,
   conferma di entrambi con “Prossimo round”, nuova mescolata sul deck successivo.
5. **Abbandono:** riconnessione entro 90 secondi; uscita esplicita o scadenza di
   un solo giocatore = vittoria/sconfitta con corone, senza gemme. Se entrambi
   scadono senza riconnettersi, o il profilo viene cancellato, partita annullata
   senza corone o gemme. Un esito già chiuso non cambia al riavvio del server.
6. **Premio:** 20 gemme per ciascun profilo distinto soltanto al completamento
   della partita intera; nessun accredito ai singoli round intermedi.
7. **Ammissione:** classificate tramite codice/invito, profili distinti nella
   stessa arena. Le stanze non diventano classificate per effetto di un aggiornamento.
8. **Migrazione e Paola:** eccezioni storiche solo non classificate come sopra;
   Paola resta gratuito e selezionabile nelle attività non classificate.

## 7. Accettazione

- Soglie: 0/99 → Valle; 100/299 → Baia; 300/599 → Città; 600+ → Spazio.
- Con 100 corone e poi una sconfitta: `crowns=80`, `peakCrowns=100`, Valle in
  classificata, Valle e Baia nelle amichevoli.
- Saldo minimo: una sconfitta da 0 non produce un numero negativo.
- Pool: l'unione dei possessi contiene un deck una sola volta, include gli
  acquisti di entrambi e non include deck di altre arene o Paola.
- Tre estrazioni senza duplicati; nessun vantaggio di probabilità per un deck
  posseduto da entrambi; errore esplicito se mancano tre deck giocabili.
- Un profilo migrato conserva gemme, acquisti e credenziali, parte da 0/0 e
  mantiene il progresso dopo un riavvio o ripristino.
- Il client legge sia snapshot precedenti senza corone sia i nuovi snapshot;
  la copia generata del catalogo corrisponde alla fonte dati.
- Le modalità esistenti e i test pertinenti continuano a passare; nessun
  contenuto mancante diventa giocabile. Tutti i 21 deck delle prime quattro
  arene sono completi e la classificata è attiva nella nuova versione locale.
- Tre round con cambio di deck, conferme, risultato aggregato e premi finali;
  nessuna doppia assegnazione dopo retry, riconnessione o riavvio.
- Un ospite che esce prima dell'inizio libera il secondo posto senza cambiare
  il codice dell'host; un altro giocatore può entrare e confermare Pronto.
- Ogni giocatore vede soltanto le proprie carte scoperte; il confronto 37–36
  assegna la vittoria al giocatore con 36 tentativi, dopo tutti e tre i round.
- Regole, corone, prezzi e ragioni dei blocchi leggibili a 320 px, con spazio
  tra tab e arena. I pannelli di attesa e risultato scorrono in orizzontale.

Task, responsabilità e risultati: [ARENAS_TASKS.md](ARENAS_TASKS.md).
