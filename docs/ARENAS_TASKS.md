# Arene — task e verifica

Riferimento: [ARENAS_SPEC.md](ARENAS_SPEC.md), versione 3, 5 novembre 2026.

L'utente ha richiesto la specifica, l'implementazione con Luna e Terra e la
revisione UI con Astra. Il lavoro usa la copia corrente, conservando le modifiche
pregresse ad account e distribuzione. Nessun commit o rilascio fa parte del task.

| Area | Responsabile | Risultato | Stato |
| --- | --- | --- | --- |
| Specifica e integrazione | Coordinatore | Quattro arene, soglie, pool e regole concordate; cataloghi server/Dart allineati | Completato |
| Dominio e contenuti | Luna — `luna_server` | Catalogo validato; 21 deck illustrati, 18 soggetti ciascuno; pipeline e provenienza | Completato |
| Profilo e menu | Luna — `luna_flutter` | Corone/record, arene storiche, selettori coerenti, negozio e accesso offline | Completato |
| Persistenza | Terra — `terra_persistence` | Migrazione SQLite, conservazione acquisti e vecchi deck gratuiti, esiti atomici e idempotenti | Completato |
| Partite classificate | Terra e Luna | Tre round individuali identici per i due giocatori; vince il minor totale tentativi | Completato |
| Lobby | Terra e Luna | Conferma Pronto; uscita ospite libera il posto mantenendo il codice; uscita host chiude | Completato |
| Compatibilità | Coordinatore e Terra | Amichevoli e vecchi client conservati; capacità nuove negoziate; Bluetooth con catalogo esteso | Completato |
| Revisione UI | Astra — `astra_ui_final`, coordinatore e Luna | Contrasto, spaziatura, negozio, selezione arena, lobby, tabelloni e risultati | Completato — nessun problema aperto |
| Verifica e compilazione | Coordinatore | Suite complete, analisi, parità catalogo e build web di pubblicazione locale | Completato |
| Matchmaking automatico | Futuro | Coda, ricerca e abbinamento per corone/arena | Fuori da questa versione |
| Acquisti in denaro | Futuro | Ricariche gemme e integrazioni store | Fuori da questa versione |

## Decisioni definitive

- Arene a 0, 100, 300 e 600 corone; la classificata segue il saldo attuale,
  le amichevoli conservano le arene raggiunte grazie al massimo storico.
- Vittoria +20 corone; sconfitta −20 fino a zero; pareggio 0.
- Amichevole: un round sul tabellone condiviso a turni.
- Classificata: tre deck diversi, sorteggiati dall'unione dei gratuiti dell'arena
  e degli acquisti di entrambi. Ogni giocatore completa il proprio tabellone
  da 12 coppie, con la stessa disposizione dell'altro.
- Una seconda carta scoperta conta un tentativo, coppia o errore. Vince la
  minore somma nei tre round; parità = pareggio. Nessuna classifica per coppie.
- Intermezzi dopo il completamento di entrambi, con conferma del prossimo round.
- Premio di 20 gemme per profilo distinto solo al completamento della partita.
  Un abbandono durante il gioco assegna corone senza gemme.
- Riconnessione entro 90 secondi. Due disconnessioni scadute annullano il match.
  Prima dell'inizio la lobby non assegna risultati, corone o premi.
- Paola rimane allenamento gratuito. Migrazione senza regali di corone,
  conservando le collezioni disponibili ai vecchi profili.

## Contenuti

378 PNG distribuiti nell'app: 216 Noto e 162 originali generati per il progetto.
Tutti i deck hanno 18 immagini diverse; nessuna immagine è identica tra deck
della stessa arena. I sei deck illustrati precedenti conservano ID e ordine.
Le fonti, i prompt, i tagli degli atlanti e gli hash sono documentati in
[DECKS.md](DECKS.md) e nei manifest. L'app usa soltanto immagini incluse e
funziona offline per i contenuti già accessibili.

## Verifica

- Server: **81/81 test** superati, inclusi migrazione, transazioni, tre round,
  minimo tentativi, pareggio, privacy dei tabelloni, lobby, riconnessione e riavvio.
- Flutter: **154/154 test** superati; controllo dei 378 PNG e delle licenze incluso.
- Dopo la correzione dell'etichetta Insetto foglia: test artwork **2/2** superati.
- Analisi Flutter: nessun problema rilevato.
- Catalogo Dart generato: allineato alla fonte JSON.
- Build web di pubblicazione locale: completata, con gli URL di produzione.
- Ultima suite completa dopo i fix di leggibilità: **154/154** test Flutter;
  analisi pulita e nuova build web riuscita. Nessuna pubblicazione eseguita.
- Revisione Astra: conclusa, nessun problema aperto.

Toolchain:
`/Users/micheletagliabue/development/flutter-sdks/mymemory-stable/bin/flutter`,
Flutter 3.47.9 / Dart 3.13.7. Il comando Flutter predefinito sul PATH è precedente.

La fase iniziale di sole basi era stata verificata con 62 test Node e 124 test
Flutter; la successiva richiesta di completamento ha esteso motore, contenuti e UI.

## Prove visive e flussi reali

File in `artifacts/arenas/`:

- `setup-classificata-320.jpg`: regole leggibili su pannello chiaro, spazio sotto
  le tab, arena/corone/record.
- `lobby-posto-libero-320.jpg`: uscita ospite e posto libero, codice conservato.
- `lobby-568.jpg`: due giocatori, conferma Pronto e uscita in orizzontale.
- `classificata-tabellone-568.jpg`: tutte le 24 carte visibili; scoperte private.
- `classificata-tentativi-finale-568.jpg` e `classificata-tentativi-premi-568.jpg`:
  tre round, totale 37–36, vittoria al minor numero di tentativi, premi e azioni.
- `negozio-insetti-320.jpg`: prezzi e ragione del blocco interamente leggibili.
- `art-*.jpg`: tavole di controllo delle quattro arene.

Nel flusso reale l'ospite è uscito e rientrato con lo stesso codice, poi entrambi
hanno confermato Pronto e completato Fattoria, Animali e Fiori e piante.
Un errore aggiuntivo dell'host ha prodotto 37–36 e la sconfitta corretta:
−20 corone e +20 gemme per l'host, +20 corone e +20 gemme per l'ospite.
La carta scoperta dall'host è rimasta coperta sul dispositivo dell'ospite.
Astra ha verificato tutti gli screenshot e chiuso la revisione senza rilievi.

L'anteprima usa due browser con profili distinti e un servizio locale con dati
di prova separati. Gli strumenti che completano i tabelloni per il collaudo
esistono soltanto fuori dal repository e non sono parte del prodotto.
