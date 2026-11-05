# Configurazione degli account Apple e Google

Il codice degli account opzionali è incluso nell'app e nel server. Nickname, avatar, colore, recupero tramite codice e gestione dei dispositivi funzionano anche senza OAuth. Apple e Google restano nascosti finché il server dispone della configurazione necessaria; su iOS servono anche una build abilitata e la configurazione di firma appropriata.

La prima release del servizio e dell'app web con gestione del profilo è stata pubblicata come **20261105T180636Z-accounts**, web **3.0.0 (30012)**. Il controllo dopo quel rilascio ha verificato la conservazione dei 25 profili, delle 25 sessioni e delle 41 registrazioni contabili preesistenti; backup coerente conservato privatamente sul server. [Ricevuta del rilascio iniziale](../artifacts/accounts-activation/foundation-deploy.json).

## Stato dell'attivazione

Configurazione aggiornata al **5 novembre 2026**:

- **Google:** progetto **SommoMemory**, ID `sommomemory-sommomi`, con tre client OAuth dedicati a web, iOS e Android. La schermata di consenso è in modalità **Production** e gli unici ambiti sono `openid`, `profile` ed `email`. La configurazione Android usa il certificato di firma delle installazioni distribuite da Google Play. [Verifica della firma Android](../artifacts/accounts-activation/android-signing.json).
- **Apple:** Sign in with Apple abilitato sull'App ID primario `cc.sommomi.mymemory`; Services ID `cc.sommomi.mymemory.accounts`, chiave dedicata `QRZ6HY8725`, team `L6CS7PYA4B`. Il callback è `/api/v1/auth/callback/apple` e le notifiche server sono su `/api/v1/auth/notifications/apple`, entrambi sotto `https://sommomemory.sommomi.cc`.
- **Firma iOS:** profilo **SommoMemory App Store Accounts Notifications**, risorsa Apple `TS467WLHTS`, UUID `dc790f0a-5752-4d01-9b8a-9b84d4ff01a7`. La build include Sign in with Apple e lo schema URL del client Google iOS.
- **Configurazione privata:** file di ambiente e override del container applicati da `/srv/mymemory/private/` su Sommonas. La chiave Apple resta in `/srv/mymemory/private/apple-signin.p8` ed è montata in sola lettura come `/run/secrets/mymemory-apple-signin.p8`. La configurazione Compose è stata validata; le ricevute contengono solo metadati. [Ricevuta della preparazione runtime](../artifacts/accounts-activation/runtime-staging.json).
- **Pacchetti nativi:** IPA e AAB firmati **3.0.0 (30012)**, con entrambi i login abilitati nella build iOS. [Ricevuta delle build](../artifacts/native-builds-30012.json).
- **Google Play:** build **30012** disponibile per i tester del canale **interno**, con pubblico di test invariato. [Verifica Google Play e browser](../artifacts/accounts-activation/browser-verification.json).
- **TestFlight:** build **30012** elaborata e in stato **IN_BETA_TESTING**, disponibile agli stessi **due tester** del gruppo **SommoMemory Internal**. Il pubblico di test è invariato. [Ricevuta TestFlight](../artifacts/testflight-upload-30012.json).

Il runtime con Apple e Google è **attivo**. La release degli account **20261105T194451Z-privacy**, derivata da **20261105T193354Z-accounts-live** con la sola precisazione del testo privacy: il profilo sincronizza gemme, collezioni e personalizzazione; i record delle partite restano sul dispositivo. La discovery pubblica restituisce entrambi i provider per web, iOS e Android. Sono confermati conservazione dei profili e delle sessioni preesistenti, integrità del database e accesso del servizio alla chiave Apple. [Ricevuta del rilascio corrente](../artifacts/accounts-activation/privacy-clarification-deploy.json), [ricevuta dell'attivazione dei provider](../artifacts/accounts-activation/provider-deploy.json).

La release corrente è **20261105T213905Z-admin**, pubblicata il 5 novembre 2026 e derivata dalla versione privacy, con l’area amministrativa protetta da passkey e statistiche operative. I sorgenti dei provider, il gioco web e la configurazione privata sono rimasti invariati; i collegamenti account e le sessioni preesistenti sono stati verificati. [Ricevuta del rilascio admin](../artifacts/admin/production-deploy.json).

Nel browser sono stati verificati la presenza dei pulsanti Apple e Google e l'apertura delle rispettive finestre ufficiali con client validi. La verifica si è fermata prima del consenso personale: nessuna identità personale è stata collegata per il collaudo. L'accesso completo e le prove su iPhone e Android fisici rimangono da eseguire. [Ricevuta delle verifiche nel browser](../artifacts/accounts-activation/browser-verification.json).

Le dichiarazioni **App Privacy** di Apple comprendono **10 tipi di dati** configurati **in bozza**. La pubblicazione dell'etichetta attende la conferma dell'utente sulla dichiarazione finale; la distribuzione interna TestFlight è già attiva. [Stato App Privacy](../artifacts/accounts-activation/browser-verification.json).

## Comportamento implementato

Il primo collegamento aggiunge un'identità al profilo ospite esistente: mantiene ID, saldo, collezioni e premi in attesa. Se l'identità appartiene già a un altro profilo, il gioco mostra un'anteprima e richiede la conferma del cambio. I due portafogli non si sommano. Il client conserva separatamente il profilo precedente, le sue credenziali e le prove pendenti per consentirne il ripristino.

Il codice di recupero e i login possono coesistere. Il server associa le identità attraverso issuer e subject verificati, senza usare l'email. Non importa nome reale, foto o email nel profilo pubblico. Avatar e colore provengono dal catalogo incluso nell'app.

Le sessioni degli account collegati durano 90 giorni; quelle degli ospiti mantengono il comportamento precedente. Aggiungere un metodo a un account già collegato, rimuoverlo, revocare dispositivi, ruotare il recupero o eliminare l'account richiede una verifica negli ultimi cinque minuti. È possibile verificare tramite un provider già collegato oppure reimmettendo il codice di recupero. L'ultimo provider può essere rimosso solo se rimane un altro metodo di accesso.

## Configurazione del server

Usare [accounts.env.example](../deploy/accounts.env.example) come modello. Gli identificativi OAuth sono pubblici; le chiavi private restano esterne alla repository. Il server non legge automaticamente un file `.env`: passare le variabili al processo o usare il file privato nella configurazione del container.

| Variabile | Valore da configurare |
| --- | --- |
| `AUTH_PUBLIC_ORIGIN` | `https://sommomemory.sommomi.cc`, origine della pagina che apre il login Apple web |
| `AUTH_GOOGLE_WEB_CLIENT_ID` | Client OAuth Google di tipo web; usato anche come server client ID dai telefoni |
| `AUTH_GOOGLE_IOS_CLIENT_ID` | Client OAuth Google per il bundle iOS `cc.sommomi.mymemory` |
| `AUTH_GOOGLE_ANDROID_CLIENT_ID` | Client OAuth Android, se da aggiungere alle audience accettate |
| `AUTH_GOOGLE_CLIENT_IDS` | Eventuali altre audience Google autorizzate, separate da virgola |
| `AUTH_APPLE_APP_ID` | `cc.sommomi.mymemory` |
| `AUTH_APPLE_SERVICE_ID` | `cc.sommomi.mymemory.accounts`, per web e Android, associato all'App ID primario |
| `AUTH_APPLE_TEAM_ID` | `L6CS7PYA4B` |
| `AUTH_APPLE_KEY_ID` | `QRZ6HY8725`, chiave dedicata a Sign in with Apple |
| `AUTH_APPLE_PRIVATE_KEY_FILE` | `/run/secrets/mymemory-apple-signin.p8` nel container |
| `AUTH_APPLE_REDIRECT_URI` | `https://sommomemory.sommomi.cc/api/v1/auth/callback/apple` |

Google richiede il client web; su iOS richiede anche il client iOS. Apple richiede App ID, Team ID, Key ID e file della chiave; su web e Android richiede inoltre Services ID e callback HTTPS. Abilitare soltanto configurazioni effettivamente completate e collaudate.

I tre identificativi client Google sono presenti nel file di ambiente privato del servizio. Il flusso implementato verifica gli ID token e non richiede di copiare un client secret Google nel server o nell'app. I valori della tabella Apple descrivono la configurazione creata; le procedure seguenti restano il riferimento per una futura ricreazione o rotazione.

Il server deve poter raggiungere `www.googleapis.com` per le chiavi pubbliche Google e `appleid.apple.com` per verifica, scambio dei codici e revoca Apple. Le sessioni SommoMemory continuano a usare `/api/v1` e `/ws`; nessuna nuova porta pubblica è necessaria.

## Configurazione Google

1. Nel progetto Google Cloud configurare nome SommoMemory, schermata di consenso, dominio, privacy e assistenza. Usare gli ambiti di autenticazione previsti dagli SDK, senza permessi per contatti, Drive o altri servizi.
2. Creare un client web e autorizzare l'origine `https://sommomemory.sommomi.cc`. Inserirne l'ID in `AUTH_GOOGLE_WEB_CLIENT_ID`.
3. Creare il client iOS per `cc.sommomi.mymemory` e impostare `AUTH_GOOGLE_IOS_CLIENT_ID`.
4. Creare la configurazione Android per `cc.sommomi.mymemory` con le impronte del certificato di firma dell'app distribuita da Google Play. La chiave upload e la firma usata sulle installazioni Play sono distinte. Configurare separatamente i certificati di debug se si prova una build locale.
5. Per iOS seguire anche la sezione di build qui sotto. Android non richiede `google-services.json` per questo flusso: riceve il server client ID dall'API. Il browser usa il pulsante ufficiale Google con un nonce associato a ciascun tentativo.

Riferimenti: [Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect), [plugin Flutter Google](https://pub.dev/packages/google_sign_in).

## Configurazione Apple

1. Abilitare Sign in with Apple sull'App ID primario `cc.sommomi.mymemory`. Rigenerare i profili di provisioning utilizzati dalle build abilitate.
2. Creare un Services ID per web e Android, associandolo allo stesso App ID primario. Registrare dominio e return URL esatti indicati sopra. Questo raggruppamento deve essere verificato con lo stesso utente sulle tre piattaforme.
3. Creare una chiave dedicata a Sign in with Apple. Conservare il file `.p8` fuori dalla repository, con permessi restrittivi e accesso al solo processo del servizio; compilare i relativi identificativi del server.
4. Configurare il server-to-server notification endpoint: `https://sommomemory.sommomi.cc/api/v1/auth/notifications/apple`.
5. Abilitare la build iOS come descritto sotto. Android usa l'attività di callback del plugin già dichiarata nel manifest. Il web apre una finestra Apple, riceve il ritorno sul server e scambia un codice temporaneo vincolato al tentativo; non richiede di aggiungere lo script Apple alla pagina principale.

Il server verifica il token, scambia il codice Apple e conserva cifrato il refresh token necessario a verifica periodica e revoca. La revoca dell'autorizzazione invalida le sessioni; il collegamento all'identificativo Apple rimane disponibile per ritrovare lo stesso portafoglio dopo un nuovo consenso. Le notifiche firmate di cancellazione dell'account Apple eliminano il profilo associato.

Il callback accetta soltanto `POST` con `application/x-www-form-urlencoded` e `response_mode=form_post`; non accetta token o codici nella query dell'URL. Per le notifiche, l'evento canonico di cancellazione permanente è `account-deleted`; `account-delete` resta un alias compatibile. Una notifica `consent-revoked` viene ordinata tramite il suo `event_time` firmato, distinto dall'`iat` della notifica: una vecchia revoca non invalida un consenso esplicito successivo. I controlli giornalieri non cambiano la data dell'autorizzazione. [Notifiche Apple](https://developer.apple.com/documentation/signinwithapple/processing-changes-for-sign-in-with-apple-accounts).

La chiave App Store Connect configurata in `~/.codex/credentials/appstoreconnect/config.json` serve alle operazioni App Store Connect, non all'accesso degli utenti. Non riutilizzarla come chiave di Sign in with Apple. Per le future operazioni App Store Connect usare l'API quando supportata e spiegare eventuali limiti prima di ricorrere a un altro strumento.

Riferimenti: [configurazione Apple web](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web), [cancellazione e revoca Apple](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple).

## Build iOS con login abilitati

I file [Accounts.defaults.xcconfig](../app/ios/Flutter/Accounts.defaults.xcconfig) mantengono la firma ospite corrente. Copiare [Accounts.local.xcconfig.example](../app/ios/Flutter/Accounts.local.xcconfig.example) in `app/ios/Flutter/Accounts.local.xcconfig`, ignorato da Git.

Impostare `GOOGLE_REVERSED_CLIENT_ID` allo schema URL inverso del client OAuth iOS, ad esempio `com.googleusercontent.apps.ID_CLIENT_IOS`. È un identificativo pubblico, non un client secret. Se si abilita Apple, impostare `SOMMOMEMORY_ENTITLEMENTS = Runner/Runner-Accounts.entitlements` soltanto dopo aver aggiornato provisioning e capability. Per una configurazione con il solo Google mantenere gli entitlement predefiniti, rimuovendo la riga Apple dall'esempio locale.

Compilare con le opzioni relative ai provider realmente configurati:

```sh
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist \
  --dart-define=ACCOUNT_APPLE_IOS_ENABLED=true \
  --dart-define=ACCOUNT_GOOGLE_IOS_ENABLED=true
```

Senza queste opzioni la build iOS nasconde i login, anche se il server li pubblica. Questo evita di mostrare un accesso che richiede capability o schema URL assenti nella build installata. Per Android e web i provider vengono scoperti dal server.

La toolchain del progetto è `/Users/micheletagliabue/development/flutter-sdks/mymemory-stable/bin/flutter` (Flutter 3.47.9); il comando `flutter` nel PATH locale può puntare a una versione precedente.

## Configurazione privata su Sommonas

Il file [accounts.compose.example.yaml](../deploy/accounts.compose.example.yaml) mostra come passare il file di ambiente e montare la chiave Apple in sola lettura. Copiarlo sul server come `/srv/mymemory/private/accounts.compose.yaml` e adattare i percorsi privati. Per il solo Google rimuovere il mount Apple. La chiave deve essere leggibile dall'utente non privilegiato del container; non copiarla nell'immagine o nei pacchetti di rilascio.

`deploy/deploy.sh` rileva questo override privato se presente e lo applica sia al rilascio sia al ripristino della versione precedente. Il file di ambiente resta sul NAS. Il runtime attivo usa l'override e la chiave nei percorsi indicati nello stato dell'attivazione, senza incorporare credenziali nell'immagine. Mantenere questa separazione nei rilasci futuri. Una configurazione senza provider continua a funzionare con profili ospiti e codice di recupero.

## Cancellazione e conservazione

La cancellazione è disponibile in Profilo → Gestisci e nella pagina `/delete-account`, utilizzabile anche senza reinstallare l'app. La pagina offre verifica e conferma tramite codice di recupero, oppure l'accesso al profilo dall'app web con Apple o Google quando configurati.

La cancellazione locale e l'accodamento delle revoche Apple sono atomici. I dati minimi cifrati per la revoca sono separati dal profilo, ritentati in caso di rete non disponibile ed eliminati a completamento o entro 30 giorni. Le impronte dei token delle sessioni eliminate rimangono per 31 giorni, senza nome o riferimento al profilo, per distinguere `PROFILE_DELETED` da una sessione semplicemente scaduta o revocata.

I dispositivi offline non ricevono la cancellazione. Alla riconnessione entro la finestra delle impronte, il client elimina cache e prove del profilo riconosciuto come cancellato. Dopo 31 giorni una vecchia sessione restituisce il generico `INVALID_TOKEN`: il client conserva prudentemente i dati recuperabili invece di dedurre una cancellazione. La copia presente sul dispositivo può essere rimossa anche cancellando i dati dell'app o del browser.

I nomi e i riferimenti al profilo eliminato vengono rimossi anche dalle stanze persistite, mantenendo la partita giocabile per l'avversario. Durante la migrazione il server ripulisce gli eventuali riferimenti a profili già assenti. I record personali restano record dell'installazione e non vengono presentati come record sincronizzati dell'account.

Il database mantiene le migrazioni additive; preservare `economy.sqlite` e `economy-capability.key` nei backup coerenti già previsti. La cifratura delle credenziali deriva da quella chiave esterna al database con separazione di dominio. Definire una scadenza dei backup e riapplicare le cancellazioni prima di rendere operativo un ripristino storico.

## Collaudo e distribuzione

Eseguire `npm test` nel server, `flutter analyze`, `flutter test` e build web/Android/iOS con la toolchain corretta. I test automatici usano provider simulati o token firmati con chiavi di collaudo; non provano l'accesso ai servizi Apple e Google reali.

Con i provider configurati, verificare su iPhone, Android distribuito da Play e browser: primo collegamento senza variazioni del saldo, accesso allo stesso profilo da un altro dispositivo, aggiunta del secondo provider, email Apple nascosta, annullamento, chiusura della finestra, perdita di rete, sessione scaduta, codice di recupero, premi offline durante un cambio, rimozione dell'ultimo metodo, revoca di un dispositivo e cancellazione dall'app e dal web. Per le pubblicazioni sugli Store mantenere App Privacy, Data safety e URL di cancellazione coerenti con i dati effettivamente trattati.

Verifica locale del 5 novembre 2026: **114 test Flutter e 56 test Node superati**, analisi Flutter senza problemi, controllo delle dipendenze server senza vulnerabilità segnalate. Sono riuscite le compilazioni web release, Android debug e iOS release senza firma; i pacchetti firmati IPA e AAB **30012** sono ora disponibili nei rispettivi canali interni descritti sopra. I test delle notifiche Apple verificano che una vecchia revoca non invalidi un consenso successivo e che una prova precedente a una revoca non possa riattivare l'accesso; la correzione è inclusa nel runtime attivo e le impronte dei sorgenti coincidono con la ricevuta del rilascio. Verificati nel browser locale anteprima e annullamento della cancellazione tramite codice, e nel browser pubblico i pulsanti e l'apertura delle finestre ufficiali Apple e Google. Rimangono da completare un accesso personale fino al consenso e il collaudo su iPhone e Android fisici.
