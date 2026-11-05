# MyMemory Together

Il memory di Michele Tagliabue, ripristinato per Android, iPhone, iPad e browser.

**Gioca:** https://mymemory.sommomi.cc · **Privacy:** https://mymemory.sommomi.cc/privacy · **Assistenza:** https://mymemory.sommomi.cc/support

## Il gioco

- Giocatore singolo con tempo, tentativi e record salvati sul dispositivo.
- Due giocatori sullo stesso dispositivo, a turni.
- Online con stanza privata e codice: Android, iOS e browser condividono lo stesso servizio.
- Bluetooth Low Energy offline nelle app Android/iOS: un telefono ospita, l'altro cerca la partita. Entrambe le app devono restare aperte; alcuni Android non supportano il ruolo host. Interoperabilità radio ancora da collaudare su due telefoni fisici.
- 6, 8, 12 o 18 coppie e tre collezioni illustrate: **Animali, Spazio, Oceano**, 18 immagini ciascuna. I 54 PNG originali a 512 px sono inclusi e disponibili offline; fonte e licenze in `docs/DECKS.md`.
- Flip 3D delle carte (320 ms), retro dedicato a ogni collezione, impostazione di sistema Riduci movimento rispettata. Collezione e difficoltà vengono ricordate alla riapertura.
- Nessun account, pubblicità o SDK di analisi.
- Interfaccia senza slogan, con modalità e configurazione separate; tabelloni completi senza scorrimento anche su iPhone SE e in orizzontale. Ogni riga contiene sempre lo stesso numero di carte, usando solo numeri di colonne che dividono esattamente il totale.

Una coppia corretta mantiene il turno; un errore mostra le carte per 900 ms, poi passa il turno. Il server decide mazzo, turni e punteggio e non invia le carte coperte. La riconnessione online conserva il posto per 90 secondi; dopo il termine si perde per abbandono. Le stanze inattive scadono dopo 24 ore.

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

Il client usa per impostazione predefinita `wss://mymemory.sommomi.cc/ws`. Per un servizio locale:

```sh
cd server
npm ci
npm test
PORT=8787 npm start
# Da un altro terminale, nella cartella app:
flutter run --dart-define=MULTIPLAYER_URL=ws://127.0.0.1:8787/ws
```

Usare l'indirizzo del computer al posto di localhost dai telefoni. Le build distribuite mantengono HTTPS/WSS. Non abilitare eccezioni al traffico in chiaro nelle build di pubblicazione.

## Build

```sh
cd app
flutter build web --release
flutter build appbundle --release
flutter build apk --release
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Android usa la **nuova app `cc.sommomi.mymemory`**, nome **MyMemory Together**, versione **3.0.0 (30004)**. La release è disponibile nei [test interni Google Play](https://play.google.com/apps/internaltest/4700857721365894827), riservati al tester proprietario. Occorre accettare l'invito nella pagina del test. La vecchia `com.michele.mymemory` è stata eliminata il **5 novembre 2026**, su conferma esplicita dell'utente; Google consente di recuperarla fino al **12 novembre 2026**. Dopo la cancellazione è stato verificato che il nuovo test interno resta attivo. Vedere `docs/ANDROID.md` per i dettagli.

La nuova chiave upload dedicata è conservata esternamente in `~/.codex/credentials/android/mymemory/`, con configurazione privata e `app/android/key.properties` locale ignorato da Git. Le release non usano la chiave debug; Google Play gestisce la firma delle installazioni distribuite dal canale interno.

iOS usa **`cc.sommomi.mymemory`**, versione **3.0.0 (30004)**, disponibile nel gruppo **MyMemory Internal** su TestFlight. Il tester proprietario è già aggiunto e il suo invito risulta accettato. Il profilo e la chiave rimangono esterni alla repository. Gli script ASC leggono la configurazione in `~/.codex/credentials/appstoreconnect/config.json`, firmano JWT brevi in memoria e non espongono credenziali. Dopo l'upload, `node scripts/testflight-finalize.mjs --finalize --build=30004 --wait=1200` verifica Apple e collega solo il gruppo interno esistente.

## Hosting e collaudo

Dopo la build web, `node scripts/prepare-web.mjs` assegna al codice JavaScript un nome basato sul suo contenuto, evitando che una copia precedente nella cache nasconda gli aggiornamenti. `bash deploy/deploy.sh` esegue questo passaggio automaticamente e pubblica una release separata su Sommonas; vedere `deploy/README.md`. Dati in volume Docker persistente; una sola istanza del servizio. Caddy gestisce HTTPS e WebSocket. Per scalare a più istanze occorrono storage transazionale e sincronizzazione condivisi.

Verificati **27 test Flutter** (motore locale, quattro viewport con safe area iOS, tastiera aperta, tutte le 36 carte visibili e selezionabili, dialoghi, flip avanti/indietro, movimento ridotto, righe complete a ogni difficoltà, decodifica di tutte le immagini e licenze, Bluetooth e riconnessione) e **11 test Node** con due client, ripristino da disco e aggiornamento di una versione web già memorizzata dal browser; build firmate Android/iOS e build web. Il Bluetooth ha ancora bisogno del collaudo fisico Android↔iPhone, Android↔Android e iPhone↔iPhone, con permessi negati, radio spenta, background e perdita di connessione. I simulatori non possono verificare questa parte radio.
