# MyMemory Together

Il memory di Michele Tagliabue, ripristinato per Android, iPhone, iPad e browser.

**Gioca:** https://mymemory.sommomi.cc · **Privacy:** https://mymemory.sommomi.cc/privacy · **Assistenza:** https://mymemory.sommomi.cc/support

## Il gioco

- Giocatore singolo con tempo, tentativi e record salvati sul dispositivo.
- Due giocatori sullo stesso dispositivo, a turni.
- Online con stanza privata e codice: Android, iOS e browser condividono lo stesso servizio.
- Bluetooth Low Energy offline nelle app Android/iOS: un telefono ospita, l'altro cerca la partita. Entrambe le app devono restare aperte; alcuni Android non supportano il ruolo host. Interoperabilità radio ancora da collaudare su due telefoni fisici.
- 6, 8, 12 o 18 coppie; giardino, spazio e mare. Nuovi simboli vettoriali, senza usare i vecchi mazzi di terzi.
- Nessun account, pubblicità o SDK di analisi.

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
flutter build apk --debug
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

Android conserva **`com.michele.mymemory`**. La scheda originale è stata ritrovata in Play Console: **non pubblicata**, ultimo artefatto **0.9 (versionCode 2)**, nessuna iscrizione a Play App Signing. La chiave di produzione originale non è stata trovata. Vedere `docs/ANDROID.md` per scheda, dichiarazioni mancanti e ripristino. `app-debug.apk` è un pacchetto di prova; le build release non vengono firmate con la chiave debug. Per Play occorrono la chiave upload corretta e `app/android/key.properties` locale (ignorato da Git) con `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. La build attuale usa versionCode 30001, superiore al massimo storico 2.

iOS usa **`cc.sommomi.mymemory`**, versione **3.0.0 (30001)**. Il profilo e la chiave rimangono esterni alla repository. Gli script ASC leggono la configurazione in `~/.codex/credentials/appstoreconnect/config.json`, firmano JWT brevi in memoria e non espongono credenziali.

## Hosting e collaudo

Dopo la build web, `bash deploy/deploy.sh` pubblica una release separata su Sommonas; vedere `deploy/README.md`. Dati in volume Docker persistente; una sola istanza del servizio. Caddy gestisce HTTPS e WebSocket. Per scalare a più istanze occorrono storage transazionale e sincronizzazione condivisi.

Verificati test Flutter (motore locale, layout 320/390/1024, BLE e riconnessione tramite socket reali), test Node con due client e ripristino da disco, build web/Android/iOS. Il Bluetooth ha ancora bisogno del collaudo fisico Android↔iPhone, Android↔Android e iPhone↔iPhone, con permessi negati, radio spenta, background e perdita di connessione. I simulatori non possono verificare questa parte radio.
