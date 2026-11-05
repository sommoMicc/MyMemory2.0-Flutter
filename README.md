# SommoMemory

Il memory di Michele Tagliabue, ripristinato per Android, iPhone, iPad e browser.

Il gioco si chiama **SommoMemory**. SKU `mymemory-ios` e bundle/package `cc.sommomi.mymemory` restano invariati. Il sito e il multiplayer usano `sommomemory.sommomi.cc`.

**Gioca:** https://sommomemory.sommomi.cc · **Privacy:** https://sommomemory.sommomi.cc/privacy · **Assistenza:** https://sommomemory.sommomi.cc/support

## Il gioco

- Giocatore singolo con tempo, tentativi e record salvati sul dispositivo.
- Due giocatori sullo stesso dispositivo, a turni.
- Online con stanza privata e codice: Android, iOS e browser condividono lo stesso servizio.
- Bluetooth Low Energy offline nelle app Android/iOS: un telefono ospita, l'altro cerca la partita. Entrambe le app devono restare aperte; alcuni Android non supportano il ruolo host. Interoperabilità radio ancora da collaudare su due telefoni fisici.
- 6, 8, 12 o 18 coppie e sette collezioni, selezionabili prima di avviare la partita. **Animali, Spazio, Oceano e Paola** sono gratuite; **Cibo (200), Sport (300), Viaggi (400)** si sbloccano con gemme. Paola contiene 18 sillabe italiane in testo leggibile. Le altre sei collezioni comprendono 108 PNG originali a 512 px, inclusi e disponibili offline; fonte e licenze in `docs/DECKS.md`.
- Flip 3D delle carte (320 ms), retro dedicato a ogni collezione, impostazione di sistema Riduci movimento rispettata. Collezione e difficoltà vengono ricordate alla riapertura.
- Suoni originali e vibrazioni per apertura delle carte, coppie, errori e cambio turno, disattivabili separatamente nelle impostazioni. Gli esiti seguono la fine reale dei flip; nessun feedback viene riprodotto entrando in una partita già in corso o dagli aggiornamenti ripetuti. I suoni rispettano il silenzioso di iOS e si fermano quando l’app passa in background.
- Le stanze piene mostrano un’anteprima dei due giocatori, dei punteggi e del risultato finale, aggiornabile senza occupare un posto. Gli avvisi hanno una superficie opaca leggibile sopra tutti gli sfondi; gli errori definitivi non mostrano una connessione ancora in corso.
- Profilo ospite con **100 gemme iniziali**, **20 gemme per partita completata e validata** e sblocchi permanenti. Salvataggio e sincronizzazione facoltativi tramite codice personale di recupero: niente email/password, pubblicità, SDK di analisi o denaro reale. Il codice consente di collegare app e browser allo stesso profilo; non compare mai nei link d’invito.
- Sfondo animato a tutto schermo e retro dedicato per ogni collezione, incluso un quaderno con sillabe per Paola. Il movimento si arresta quando l’app è sospesa o con Riduci movimento.
- Interfaccia senza slogan, con modalità e configurazione separate; tabelloni completi senza scorrimento anche su iPhone SE e in orizzontale. Ogni riga contiene sempre lo stesso numero di carte, usando solo numeri di colonne che dividono esattamente il totale.

Una coppia corretta mantiene il turno; un errore mostra le carte per 900 ms, poi passa il turno. Punteggio, coppie trovate e risultato compaiono solo dopo l’apertura completa delle carte; il cambio turno aspetta la completa richiusura. Durante qualunque flip il tabellone resta bloccato, in locale, online e Bluetooth. Gli aggiornamenti remoti attendono in ordine la fine reale delle animazioni; il movimento ridotto non aggiunge attese artificiali. Il server decide mazzo, turni e punteggio e non invia le carte coperte. La riconnessione online conserva il posto per 90 secondi; dopo il termine si perde per abbandono. Le stanze inattive scadono dopo 24 ore.

## Gemme, profilo e inviti

Le gemme e le collezioni possedute sono conservate in transazioni SQLite sul server, con richieste idempotenti e un registro degli accrediti. Le credenziali del profilo restano nel Keychain/Keystore dell’app; sul web il salvataggio appartiene a quel browser e dominio. Il codice personale permette di ritrovare lo stesso profilo su un altro dispositivo, dopo anteprima e conferma, senza sommare i saldi dei due ospiti. È possibile mostrare, ruotare il codice, scollegare un dispositivo o eliminare il profilo.

In multiplayer basta che chi crea la stanza possieda il deck. Le partite online completate premiano ciascun profilo distinto una sola volta, senza premi per abbandono. Per partite locali e Bluetooth l’app prepara online due tabelloni per la configurazione scelta e conserva le prove delle partite finite da sincronizzare. Senza un tabellone preparato si può sempre giocare in modalità pratica, senza gemme. I deck già posseduti restano disponibili offline. Questa verifica blocca premi doppi e prove incoerenti, ma non certifica il gioco umano; le ricariche a pagamento non sono implementate. Contratto completo in `docs/ECONOMY_PROTOCOL.md`.

Gli inviti condivisi usano `https://sommomemory.sommomi.cc/invite/CODICE`. iOS Universal Links e Android App Links richiedono la build 30009 o successiva e le associazioni pubbliche del dominio. Rimangono compatibili i precedenti `/?room=CODICE` sul nuovo dominio. Su richiesta dell’utente viene mantenuto solo `sommomemory.sommomi.cc`; il vecchio hostname non è più pubblicato. Se il browser mantiene aperto il sito, l’invito offre **Apri nell’app** come azione esplicita; il codice della stanza resta disponibile anche per entrare dal browser. I link non trasportano credenziali del profilo. Un invito ricevuto durante una partita chiede conferma prima di abbandonarla, senza ricreare il profilo. Limiti Safari e verifica fisica in `docs/DEEP_LINKS.md`.

## Struttura e recupero

| Percorso | Contenuto |
|---|---|
| `app/` | Applicazione unica Flutter, Android + iOS + web |
| `server/` | Servizio Node, WebSocket e pagine privacy/assistenza |
| `deploy/` | Container, release, volume persistente e route Caddy su Sommonas |
| `scripts/` | Icone riproducibili e operazioni App Store Connect con chiave esterna |
| `docs/RELEASE.md` | Firma, pubblicazione, TestFlight e verifiche residue |
| `legacy/AUDIT.md` | Confronto dei progetti storici e provenienza delle regole |
| `old/`, `new/` | Sorgenti Flutter storici conservati dalla repository originale; non compilati |

La storia Git della repository Flutter è conservata. Il vecchio backend Node/Socket.IO/MySQL è stato esaminato ma sostituito: manteneva credenziali e fiducia nel client non adatte al nuovo servizio. Il Java originale e le copie di consultazione dei repository rimangono nell'area di lavoro, fuori dai nuovi pacchetti.

## Sviluppo

Toolchain verificata: **Flutter 3.47.9 / Dart 3.13.7**, JDK 17, Android SDK 36, Xcode 27.2. Server verificato con Node 22.23 e container Node 24.22.1. Le versioni delle dipendenze sono bloccate nei lockfile.

```sh
cd app
flutter pub get
flutter analyze
flutter test
flutter run
```

Il client usa per impostazione predefinita `wss://sommomemory.sommomi.cc/ws`. Per un servizio locale:

```sh
cd server
npm ci
npm test
PORT=8787 npm start
# Da un altro terminale, nella cartella app:
flutter run --dart-define=MULTIPLAYER_URL=ws://127.0.0.1:8787/ws --dart-define=PROFILE_API_URL=http://127.0.0.1:8787/api/v1
```

Dai telefoni, usare un servizio HTTPS/WSS raggiungibile: l’API del profilo consente HTTP soltanto su localhost per lo sviluppo. Le build distribuite mantengono HTTPS/WSS. Non abilitare eccezioni al traffico in chiaro nelle build di pubblicazione.

## Build

```sh
cd app
flutter build web --release
flutter build appbundle --release
flutter build apk --release
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Android usa la **nuova app `cc.sommomi.mymemory`**, nome **SommoMemory**, versione **3.0.0 (30011)**. Il nome nel launcher è **SommoMemory**; la scheda Store ha il nuovo nome salvato in bozza e Google mostra un nome temporaneo fino alla prima revisione. La release è disponibile nei [test interni Google Play](https://play.google.com/apps/internaltest/4700857721365894827), riservati al tester proprietario. Occorre accettare l'invito nella pagina del test. La vecchia `com.michele.mymemory` è stata eliminata il **5 novembre 2026**, su conferma esplicita dell'utente; Google consente di recuperarla fino al **12 novembre 2026**. Dopo la cancellazione è stato verificato che il nuovo test interno resta attivo. Vedere `docs/ANDROID.md` per i dettagli.

La nuova chiave upload dedicata è conservata esternamente in `~/.codex/credentials/android/mymemory/`, con configurazione privata e `app/android/key.properties` locale ignorato da Git. Le release non usano la chiave debug; Google Play gestisce la firma delle installazioni distribuite dal canale interno.

iOS usa **`cc.sommomi.mymemory`**, versione **3.0.0 (30011)**, disponibile nel gruppo **SommoMemory Internal** su TestFlight per i due tester esistenti autorizzati. Il tester proprietario è già aggiunto e il suo invito risulta accettato. Il profilo e la chiave rimangono esterni alla repository. In caso di interruzione dopo l’invio completo dei byte, `node scripts/testflight-upload.mjs --commit-only artifacts/SommoMemory-3.0.0-30011.ipa` riprende soltanto la conferma della ricevuta esistente, verificando versione e impronte senza creare un altro upload. Gli script ASC leggono la configurazione in `~/.codex/credentials/appstoreconnect/config.json`, firmano JWT brevi in memoria e non espongono credenziali. Dopo l'upload, `node scripts/testflight-finalize.mjs --finalize --build=30011 --wait=1200` verifica Apple e collega solo il gruppo interno esistente. Per il gruppo con due tester occorre anche `--additional-tester=ID_TESTER_ESISTENTE_AUTORIZZATO`: lo script verifica l’insieme esatto e non crea tester o inviti.

## Hosting e collaudo

Dopo la build web, `node scripts/prepare-web.mjs` assegna al codice JavaScript un nome basato sul suo contenuto, evitando che una copia precedente nella cache nasconda gli aggiornamenti. `bash deploy/deploy.sh` esegue questo passaggio automaticamente e pubblica una release separata su Sommonas; vedere `deploy/README.md`. Dati in volume Docker persistente; una sola istanza del servizio. Caddy gestisce HTTPS e WebSocket. Per scalare a più istanze occorrono storage transazionale e sincronizzazione condivisi.

Verificati **91 test Flutter** (motore locale, quattro viewport con safe area iOS, tastiera aperta, tutte le 36 carte visibili e selezionabili, dialoghi, flip avanti/indietro, eventi solo a fine animazione, movimento ridotto e pausa dell’app, blocco durante i flip, aggiornamenti remoti anticipati, rotazione e nuova partita senza callback obsolete, righe complete a ogni difficoltà, decodifica di tutte le immagini e licenze, Bluetooth e riconnessione) e **31 test Node** con credenziali, ripristino del profilo, sblocchi atomici, premi e prove di partita, migrazione del database, due client e ripristino da disco e aggiornamento di una versione web già memorizzata dal browser; build firmate Android/iOS e build web. Il Bluetooth ha ancora bisogno del collaudo fisico Android↔iPhone, Android↔Android e iPhone↔iPhone, con permessi negati, radio spenta, background e perdita di connessione. I simulatori non possono verificare questa parte radio.
