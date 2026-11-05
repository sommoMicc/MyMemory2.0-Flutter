# Piano degli account opzionali di SommoMemory

Stato: implementazione nel codice, con configurazione OAuth e collaudo dei provider reali da completare · 5 novembre 2026. Vedere [configurazione degli account](ACCOUNTS_SETUP.md) per attivazione e limiti di conservazione.

SommoMemory deve permettere di personalizzare il proprio giocatore e continuare a giocare senza registrazione. Collegare Apple o Google aggiunge un modo semplice per recuperare lo stesso profilo su iPhone, Android e browser, conservando gemme e collezioni. Il profilo ospite attuale rimane la base del sistema.

## Esperienza del giocatore

All'apertura si entra direttamente nel gioco. La schermata Profilo offre tre sezioni:

| Sezione | Contenuto previsto |
| --- | --- |
| Il mio profilo | Nickname, avatar, colore del profilo, gemme e collezioni |
| Salva e collega | Continua con Apple, Continua con Google, codice di recupero |
| Gestisci | Metodi collegati, dispositivi, esci, elimina profilo |

Nickname, avatar e colore sono modificabili anche da ospite. Per la prima versione, gli avatar provengono da un catalogo incluso nell'app e i colori da una palette accessibile: nessun caricamento di fotografie. Il nickname mantiene il limite attuale di 24 caratteri e non deve essere univoco. Il nome reale e la foto del provider non sostituiscono automaticamente le scelte del giocatore; l'email non compare agli avversari.

La sezione di salvataggio spiega il vantaggio concreto: «Ritrova gemme e collezioni su altri dispositivi». Non interrompe le partite e non impone un accesso al primo avvio. Un accesso annullato lascia il giocatore esattamente nel profilo precedente.

Distinguere tre informazioni indipendenti: presenza di un codice di recupero, provider collegati e stato della sincronizzazione. Un account può avere Apple, Google e un codice contemporaneamente; anche un account collegato può essere offline. Il campo attuale `activated` indica il recupero tramite codice e non va reinterpretato come presenza di un login sociale.

## Cosa esiste già

Il servizio Node conserva profili, sessioni, gemme, sblocchi e registro delle transazioni in SQLite. Il client Flutter gestisce credenziali nel deposito sicuro, cache offline, richieste idempotenti e premi in attesa associati al `profileId`. Sono già disponibili modifica del nome, recupero con anteprima, rotazione del codice, uscita e cancellazione.

I record personali sono invece preferenze locali (`best.<numero coppie>`), condivise dall'installazione. Non sono ancora statistiche sincronizzate di un account. Nella prima versione rimangono record del dispositivo, con etichetta esplicita; una futura sincronizzazione richiederà dati separati per profilo e regole di importazione. Suoni, vibrazioni e altre preferenze del dispositivo restano locali.

Riferimenti al comportamento attuale: [contratto del profilo](ECONOMY_PROTOCOL.md), [client](../app/lib/economy.dart), [schermata Profilo](../app/lib/ui/profile_panel.dart), [archivio server](../server/src/economy.mjs).

## Collegamento e recupero senza perdere progressi

| Situazione | Comportamento previsto |
| --- | --- |
| L'ospite collega un'identità Apple o Google mai usata | Collegare l'identità al profilo corrente. `profileId`, saldo, collezioni, codice e premi in attesa restano gli stessi. Nessun nuovo bonus iniziale. |
| Il provider identifica il profilo già aperto | Confermare l'accesso senza duplicare account o premi. |
| Il provider identifica un altro profilo | Mostrare nickname, saldo e collezioni del profilo trovato; chiedere prima di sostituire quello corrente. Offrire Annulla e un percorso per salvare il profilo corrente con un codice. |
| Un giocatore con account aggiunge un altro provider | Richiedere una verifica recente dell'accesso attuale e quella del nuovo provider. Collegare solo se la nuova identità è libera. |
| Il secondo provider appartiene a un altro profilo | Rifiutare il collegamento con un messaggio chiaro. Non spostare identità o unire profili. |
| Il giocatore esce | Revocare la sessione del dispositivo e pulire la sua copia privata. Tornare all'esperienza ospite senza scollegare Apple o Google dall'account sul server. |

Apple e Google possono identificare la stessa persona con email differenti, oppure con email uguali: nessuno dei due casi prova che i profili vadano uniti. L'associazione usa l'identificativo verificato del provider. Google prescrive di usare `sub`, non l'email, come identificatore stabile. [Documentazione Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect).

Il cambio verso un altro profilo va completato fuori da una partita attiva, dopo aver tentato la sincronizzazione dei premi pendenti. Se il tentativo fallisce, conservare prove e sessione precedente in un archivio sicuro separato per profilo, finché il giocatore sceglie come procedere. Non attribuire al nuovo profilo i premi guadagnati dal precedente. Prima della sostituzione deve essere possibile conservare un metodo di recupero del vecchio profilo; il cambio non lo elimina.

Il server prepara un'anteprima con una conferma monouso e di breve durata, vincolata alla sessione iniziale, all'operazione e al profilo trovato. Solo la conferma finale emette la sessione del profilo di destinazione. Retry e doppio tocco restituiscono lo stesso esito senza creare altre associazioni. Il collegamento di una nuova identità e l'eventuale creazione di un profilo avvengono in transazione.

## Architettura proposta

Estendere il backend Node e SQLite esistente con un modulo di autenticazione. I provider dimostrano l'identità; il backend continua a decidere sessioni, proprietà delle collezioni e saldo. Questa scelta riutilizza l'economia attuale e mantiene un solo identificativo interno del giocatore.

Il client usa [google_sign_in](https://pub.dev/packages/google_sign_in) e [sign_in_with_apple](https://pub.dev/packages/sign_in_with_apple), verificandone compatibilità e versioni durante l'implementazione. Entrambi documentano supporto per Android, iOS e web; Apple su Android richiede anche il flusso web e un callback server. Sul web Google richiede il pulsante fornito dal proprio SDK. Le verifiche crittografiche sul server devono usare una libreria mantenuta, con dipendenze bloccate nel lockfile.

| Dato | Modifica prevista |
| --- | --- |
| `profiles` | Aggiungere `avatar_id` e `accent_id` con valori predefiniti; mantenere ID, portafoglio, revisioni e recupero esistenti. |
| `auth_identities` | Identità collegate con `profile_id`, provider, issuer canonico, subject e date. Vincolo univoco su provider, issuer e subject; nella prima versione, una sola identità per provider e profilo. |
| `auth_attempts` | Tentativi brevi con operazione, dispositivo iniziale, nonce, state, scadenza e consumo atomico; nessun token nei log. |
| Sessioni | Estendere `tokens` con ID pubblico di sessione, nome facoltativo del dispositivo, ultimo utilizzo e scadenza. Conservare solo l'impronta del segreto. |
| Credenziali del provider | Conservare cifrati soltanto i token necessari a verifica e revoca, con chiave esterna al database e alla repository. |

La migrazione è additiva e versionata. I vecchi client continuano a leggere gli stessi campi e a usare le stesse sessioni; `activated` e `recoveryVersion` mantengono il significato attuale. Il nuovo client usa campi aggiuntivi come `recoveryEnabled`, `linkedProviders`, `avatarId` e `accentId`, con valori predefiniti se assenti. Le versioni precedenti che modificano solo il nome non devono cancellare avatar e colore.

Le identità complete e i metadati dei dispositivi sono disponibili soltanto alle rispettive API private. Non aggiungerli alla risposta pubblica di anteprima del codice di recupero. Se si mostrano avatar agli avversari, estendere separatamente i messaggi online e Bluetooth con soli identificativi del catalogo, validati e compatibili con i client precedenti.

### Flussi e protezioni

Ogni accesso comincia con un tentativo creato dal server. Usare le interfacce native dei provider sui telefoni e i flussi web supportati nel browser; nessuna schermata interna che richieda la password Apple o Google. Nei flussi con redirect, verificare `state`; dove supportato usare Authorization Code con PKCE S256. Il server verifica firma, issuer, audience consentita, scadenza e nonce previsto per lo specifico tentativo. Non basta decodificare il token. [Google OpenID Connect](https://developers.google.com/identity/openid-connect/openid-connect), [verifica Apple](https://developer.apple.com/documentation/signinwithapple/verifying-a-user).

Separare esplicitamente le operazioni di accesso, collegamento e verifica recente. Un risultato di accesso non autorizza implicitamente a collegare un'identità. Per un account già collegato, aggiunta e rimozione dei metodi, rotazione del recupero, revoca di tutte le sessioni ed eliminazione richiedono una verifica recente tramite un provider già collegato oppure la reimmissione del codice di recupero valido. La sola sessione persistente del dispositivo non basta.

I callback accettano solo redirect registrati e formati previsti. Il callback Apple deve gestire anche `form_post`, con parser dedicato, limiti e verifica del tentativo: il server attuale accetta solo JSON nelle API e non supporta ancora questa risposta. Non applicare al callback esterno la stessa verifica Origin delle richieste dell'app. Il ritorno all'app usa un codice di consegna monouso vincolato al dispositivo; token SommoMemory e credenziali del provider non entrano negli URL di ritorno o d'invito.

Riutilizzare i token opachi SommoMemory per REST e WebSocket. Le credenziali Apple e Google non passano agli avversari o via Bluetooth. Su app conservare le sessioni in Keychain/Keystore. Sul web il deposito attuale rimane accessibile al codice dell'origine: non descriverlo come equivalente al Keychain; mantenere controlli sugli script, scadenze e revoca server. Prevedere limiti dei tentativi, rotazione delle chiavi pubbliche dei provider ed errori di rete che lascino utilizzabile la cache offline.

### API da aggiungere

Percorsi proposti sotto `/api/v1`, da formalizzare nel contratto prima dello sviluppo:

| Metodo e percorso | Scopo |
| --- | --- |
| `GET /auth/providers` | Elencare i soli provider configurati e abilitati per la piattaforma. |
| `POST /auth/attempts` | Avviare accesso, collegamento o verifica recente, vincolati alla sessione corrente. |
| `POST /auth/exchange` | Validare le credenziali native e produrre esito o anteprima di cambio profilo. |
| `POST /auth/callback/apple` | Ricevere il ritorno Apple nel formato `form_post`, senza credenziali nella query. |
| `POST /auth/confirm` | Consumare la conferma e applicare l'operazione prevista. |
| `GET /profile/identities` | Elencare i metodi collegati, senza subject o token. |
| `DELETE /profile/identities/:provider` | Scollegare un metodo con verifica recente. |
| `GET /profile/sessions` | Elencare le sessioni, identificando quella corrente. |
| `DELETE /profile/sessions/:id` | Revocare un dispositivo. |

Estendere `PATCH /profile` per nickname, avatar e colore, validando il catalogo sul server. Integrare la verifica recente in `DELETE /profile` e nelle operazioni sensibili del recupero. Le rotte esistenti di gemme e partite continuano a usare il medesimo `profileId`.

## Gestione e cancellazione

Non consentire di scollegare l'ultimo metodo di accesso senza un'alternativa verificata. Se resta soltanto il codice, chiedere di conservarlo prima di rimuovere l'ultimo provider. Uscire da un dispositivo, scollegare un provider ed eliminare il profilo sono azioni distinte, spiegate nella schermata di conferma.

L'eliminazione rimuove profilo, identità, sessioni, recupero, gemme e collezioni; elimina anche cache e operazioni pendenti sui dispositivi quando ricevono la revoca. Verificare la gestione dei riferimenti nelle stanze persistite: la cancellazione di un account non deve impedire di terminare la partita all'avversario. Gli altri dispositivi, al successivo collegamento, non devono ricreare l'account né caricarvi le vecchie prove.

Per Apple prevedere scambio iniziale del codice, conservazione protetta del refresh token necessario e revoca all'eliminazione. Gestire notifiche del provider e verifiche periodiche; una revoca rende inutilizzabili le sessioni interessate. Una revoca esterna temporaneamente fallita non deve bloccare la cancellazione locale: accodare un tentativo con i soli dati necessari, cancellandoli al completamento. [Apple TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple).

Prevedere una pagina `https://sommomemory.sommomi.cc/delete-account` con accesso Apple, Google o codice e richiesta di cancellazione, utilizzabile anche senza reinstallare l'app. Google Play richiede un percorso nell'app e una risorsa web per richiedere l'eliminazione quando l'app permette la creazione di account. [Requisiti Google Play](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en).

## Configurazione dei provider e distribuzione

Per iOS proporre Apple e Google insieme. La linea guida Apple 4.8 richiede, nei casi di login sociale come questo, un'opzione equivalente con specifiche protezioni della privacy: Sign in with Apple è la scelta prevista per soddisfarla. Mantenere il gioco accessibile senza login e la cancellazione dall'app. [App Review Guidelines 4.8 e 5.1.1](https://developer.apple.com/app-store/review/guidelines/).

Prima dell'attivazione:

- **Apple:** abilitare Sign in with Apple sull'App ID `cc.sommomi.mymemory`, aggiornare entitlement e profili di firma, creare un Services ID associato all'App ID primario per web e Android, registrare dominio e callback HTTPS. Configurare la chiave dedicata a Sign in with Apple e le notifiche server. Verificare che l'identità sia riconosciuta sulle tre piattaforme con il raggruppamento previsto. [Configurazione Apple per il web](https://developer.apple.com/help/account/capabilities/configure-sign-in-with-apple-for-the-web).
- **Google:** configurare progetto, consenso e client OAuth per iOS, Android e web; registrare origini e redirect esatti. Su Android includere il certificato di firma Google Play dell'app distribuita, distinto dalla chiave upload, e separare le configurazioni di sviluppo.
- **Segreti:** tenere chiavi e client secret solo sul server o nelle configurazioni private esterne. La chiave App Store Connect esistente serve alle operazioni di distribuzione e non va riutilizzata come chiave di login degli utenti. Per future operazioni App Store Connect usare l'API configurata, segnalando prima eventuali limiti che richiedano un altro strumento.
- **Informative:** aggiornare privacy, supporto, dichiarazioni App Privacy e Data safety per i dati effettivamente introdotti. Stabilire scadenza dei backup e procedura che riapplichi le cancellazioni dopo un ripristino, senza far ricomparire account eliminati.

Su Android e web l'obiettivo è offrire entrambi i provider, così un account creato su iPhone rimane accessibile anche altrove. I pulsanti si mostrano solo quando il percorso completo della piattaforma è configurato; un provider disabilitato non impedisce agli ospiti o ai profili con codice di giocare.

## Ordine di implementazione

1. **Profilo personalizzabile:** migrazione additiva, catalogo avatar e colori, aggiornamento di `ProfileData` e `ProfilePanel`, modifica del nome compatibile con i vecchi client. Consegna verificabile senza configurare provider.
2. **Fondamenta degli account:** tabelle identità e tentativi, validazione server, collegamento dell'ospite, anteprima e conferma, verifica recente, gestione della sessione e conservazione dei premi durante il cambio. Consegna verificabile con provider simulati nei test.
3. **Apple e Google reali:** configurazioni esterne, plugin Flutter, callback, stesso account tra iOS, Android e web. Mantenere le funzionalità nascoste finché i flussi reali non superano il collaudo.
4. **Gestione completa:** dispositivi, scollegamento, revoche, cancellazione dall'app e dal web, pulizia delle stanze e informative. Questa fase è necessaria prima di distribuire la creazione di account al pubblico.
5. **Collaudo e rilascio:** controlli automatici, prove fisiche, TestFlight e test interno Google Play; attivazione graduale tramite configurazione del server. Un rollback dei provider conserva profili, dati e recupero tramite codice.

File principali da estendere: `app/lib/economy.dart`, `app/lib/ui/profile_panel.dart`, `app/lib/main.dart`, `server/src/economy.mjs`, `server/src/economy-http.mjs`, `server/src/server.mjs`. Separare la logica nuova in moduli dedicati come `app/lib/account.dart`, `server/src/auth.mjs` e `server/src/auth-http.mjs`. Aggiornare il contratto API e la documentazione di rilascio quando il comportamento viene implementato.

## Criteri di accettazione

- Un ospite personalizza il profilo e usa tutte le modalità di gioco senza login; resta possibile giocare offline con le collezioni disponibili.
- Collegare il primo provider conserva esattamente ID, saldo, sblocchi e premi in attesa. Non viene accreditato un altro bonus iniziale.
- Lo stesso provider riapre lo stesso profilo su iOS, Android e web; Apple con email nascosta e Google con email modificata non creano duplicati.
- Due provider si collegano allo stesso profilo soltanto tramite operazione esplicita. Conflitti, doppi tocchi e richieste concorrenti non spostano un'identità fra account.
- Accesso annullato, rete interrotta e callback ripetuto non cambiano il profilo. Un cambio confermato non mescola portafogli, cache o premi dei due giocatori.
- Token con firma, issuer, audience o nonce errati, tentativi scaduti e risposte riutilizzate vengono rifiutati. Nessun segreto appare nei log, negli inviti o nei messaggi multiplayer.
- Uscita, revoca di un dispositivo, rimozione di un provider ed eliminazione hanno gli effetti distinti previsti; la rimozione dell'ultimo metodo non lascia un account irrecuperabile.
- Le build precedenti mantengono accesso, recupero e gemme dopo la migrazione; cambiare il nome da un vecchio client conserva i nuovi campi.
- Su telefoni e browser reali verificare selezione dell'account, annullamento, ritorno all'app, riavvio durante il login, codice di recupero, revoca esterna e cancellazione da web. Eseguire i test Node e Flutter pertinenti e l'analisi statica prima del rilascio.

Foto personalizzate, fusione di profili, email e password proprie, classifiche e sincronizzazione dei record locali possono essere valutate dopo questa prima versione.
