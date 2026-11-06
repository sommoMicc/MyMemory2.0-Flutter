# SommoMemory profiles and gems — API v1

Base URL: `https://sommomemory.sommomi.cc/api/v1`. JSON requests and responses;
`Authorization: Bearer <token>` on authenticated routes. No cookies, app
passwords, money, purchases or transfers. Optional Apple/Google login extends the
same profiles; it is disabled until configured. All responses use
`Cache-Control: no-store`. Error shape: `{ "error": { "code": "…", "message": "…" } }`.

## Catalog and profile

`GET /catalog` is public and returns `decks`, `rules`, `arenas` and `rankedEnabled`.
It includes only ready deck content. Stable legacy deck IDs/prices:
`garden:0`, `cosmos:0`, `ocean:0`, `paola:0`, `food:200`, `sports:300`, `travel:400`.
New profiles start with `garden`, `farm`, `flora` and `paola`. Arena thresholds
unlock the other free collections. Existing profiles retain `cosmos` and `ocean`
through `legacyDecks`, plus all purchased decks, for non-ranked use even before
their arena is reached. This grants no crowns or other decks of that arena.
Unlocks are permanent within a profile; new paid purchases require a reached
arena. The canonical 21-deck arena catalog plus Paola is in
`server/catalog/arenas.v1.json` and [ARENAS_SPEC.md](ARENAS_SPEC.md).
`paola` is the text-based Paola collection: string IDs 0–17 map in order to
PA, PE, PI, PO, PU, LA, LE, LI, LO, LU, MA, ME, MI, MO, MU, SA, SE, SI.

Authenticated profile JSON is `{id,displayName,avatarId,accentId,activated,recoveryEnabled,linkedProviders,recoveryVersion,gems,ownedDecks,legacyDecks,revision,crowns,peakCrowns,currentArenaId,unlockedArenaIds,soloBestAttempts}`. `soloBestAttempts`
maps difficulty keys `"6"`, `"8"`, `"12"`, `"18"` to the minimum validated number
of attempts; missing keys mean no completed game yet. Solo transcripts update
these records by minimum, so another device cannot replace a better record with
a worse one. `activated`
retains its original meaning (recovery code enabled); it does not indicate a
social login. Appearance defaults to `fox` and `forest`, providers to an empty
list, and `recoveryEnabled` falls back to `activated` for older services. Display name
may be empty; limit 24 Unicode characters. Treat the server snapshot as
authoritative and ignore lower revisions for the **same profile ID**. Replacing
the profile changes the ID/revision scope and must clear profile-specific caches.

Arena progression metadata is additive: `crowns` and `peakCrowns` start at zero
for existing and new profiles, with `peakCrowns >= crowns`. `currentArenaId` is
derived from current crowns; `unlockedArenaIds` from the historical peak.
Thresholds are `wild_valley:0`, `coral_bay:100`, `grand_city:300`,
`space_frontier:600`. Older cached responses without these counters default to
zero; a missing peak defaults to the current crown value. Clients derive arena
IDs from the versioned catalog rather than accepting cached IDs as authority.
These fields cannot be set through `PATCH /profile`. Ranked matches are admitted
by invitation with two distinct profiles in the same current arena; automatic
matchmaking remains a future feature. See [arena specification](ARENAS_SPEC.md) and
[implementation tasks](ARENAS_TASKS.md).

| Method/path | Body | Response |
| --- | --- | --- |
| POST `/profiles` (public) | `{}` | 201 `{token,profile}`: anonymous guest, 100 welcome gems once |
| GET `/profile` | — | `{profile}` |
| PATCH `/profile` | `{displayName?,avatarId?,accentId?}` | `{profile}`; omitted fields preserved |
| GET `/profile/ledger` | — | `{entries:[{source,delta,createdAt}]}` (latest 50) |
| POST `/profile/recovery` | `{displayName?}` | `{recoveryCode,profile}`: activate optional sync |
| POST `/profile/recovery/rotate` | `{}` | `{recoveryCode,profile}`: invalidate old recovery code |
| POST `/profiles/restore/preview` (public) | `{recoveryCode}` | `{profile}`; no token issued |
| POST `/profiles/restore` (public) | `{recoveryCode,confirmReplace:true}` | `{token,profile}`; new device session on existing profile |
| POST `/profile/logout` | `{}` | `{loggedOut:true}`; current token revoked only |
| DELETE `/profile` | `{confirmDelete:true}` | `{deleted:true}`; profile/wallet/unlocks/recovery/sessions removed |

Keep the opaque token in platform secure storage; web uses app-local storage with
the usual browser/XSS risk. Recovery codes are credentials too: never log, relay
over Bluetooth, place in invitation URLs or attach to analytics. Show/export/QR
only after an explicit profile action. The server stores token/recovery hashes,
not plaintext. A recovery code is a strong random 160-bit value in grouped
`SMM-XXXX-…` form, case-insensitive, hyphens/spaces optional.

The server cannot retrieve an old recovery code. Cache it securely on the device
that activated it; restored devices can cache the user-supplied code. Repeating
activation returns 409 `RECOVERY_ALREADY_ACTIVE`, without rotating. If a device
has no cached code, offer explicit rotation. Rotation leaves already-authenticated
devices signed in; logout revokes only the current device. At most 32 device
tokens are retained (oldest revoked). Deletion invalidates all devices/codes.
`recoveryVersion` is a nonsecret counter: 0 before activation, 1 on activation,
incremented on each rotation. Cache the version with the recovery code. When a
fresh profile snapshot reports a different version, invalidate the cached code
without logging out; a different device may have rotated it. Wallet/name changes
do not change this counter. Restore returns the current version with the profile.

Always preview restore and ask before replacing local profile data, especially a
guest with gems/unlocks. `confirmReplace:true` is required by the API, but the UI
owns the actual confirmation. Restore performs **no merge, transfer or new welcome
grant**. Two copies of a token point to one wallet. A discarded guest is a separate
profile; do not silently delete it or claim its value moved. Preserve a recovery
code if the user wants to return to it. Without both token and recovery code, a
profile cannot be recovered; there is no support/email override.

## Unlocks and offline preparation

`POST /wallet/unlock {deckId,requestId}` returns
`{profile,deckId,unlocked,alreadyOwned}`. An owned deck is never charged again,
even with a different request ID. Insufficient funds: 409 `INSUFFICIENT_GEMS`.
Unknown or unavailable deck: 400 `INVALID_DECK`. An unreached arena returns
403 `ARENA_LOCKED`; an already owned historical purchase is never charged again.

`requestId` is a client-generated UUID or 8–80 `[A-Za-z0-9_-]` characters.
Reuse it for a network retry of the **same action**, not another action. Reusing
one for different data on the same endpoint/profile returns 409
`IDEMPOTENCY_CONFLICT`. A retried result includes a fresh profile snapshot.
Request-result records expire after 31 days (maximum 10,000/profile); permanent
deck ownership and ledger uniqueness still prevent double charging or crediting
after this retry-cache expiry.

`POST /games/tickets {mode,pairs,theme,requestId}` returns
`{ticket:{id,mode,pairs,theme,seed,board,expiresAt,guestClaimToken?}}`.
Modes: `solo`, `local`, `bluetooth`; pairs: 6, 8, 12, 18. `board` is the exact
server-shuffled array of string pair IDs `"0"`…`"17"` (two of each selected ID).
Use this board to play; `seed` is a server-issued nonce, not a Dart `Random` seed.
Do not reshuffle or regenerate the board. Expiry is a Unix timestamp in ms,
30 days after issuance. The owner must own the deck when obtaining the ticket.

`POST /games/tickets/batch {requests:[{mode,pairs,theme,requestId},…]}` returns
`{tickets:[…]}` in input order. Maximum 12; atomic all-or-nothing. Clients should
prefetch two tickets for the selected configuration, then warm other configurations
in the background, respecting a 100-ticket/profile/24h limit. Each ticket is one
rewardable game; never reuse a ticket to start a second game. A retry with the
same request ID returns the same ticket and Bluetooth capability.

Local multiplayer and Bluetooth still use the prepared-ticket reward mechanism.
Solo games use the offline journal below and need no prepared tickets or prior
connection, including for completion gems and permanent deck purchases.

## Offline solo journal

On first launch the client creates a guest immediately, with the usual 100
welcome gems and free decks, and securely saves a cryptographically random
32-byte base64url `bootstrapToken` (43 characters). Register it using public
`POST /profiles {bootstrapToken}`. The response is the usual `{token,profile}`;
`token` is that credential. An identical retry after a lost response or restart
returns the same profile, without another welcome grant. Empty `{}` preserves
the legacy profile-creation API. Only hashes are stored by the server. Repeating
registration cannot revive a session revoked by logout, device management,
expiry, or profile deletion. The client remaps its local guest ID and pending
journal to the returned server profile ID before uploading operations.

`POST /solo/operations` is authenticated and accepts one of:

```json
{"kind":"complete","requestId":"operation_nonce","gameId":"unique_game_nonce","theme":"garden","pairs":6,"board":[0,0,1,1,2,2,3,3,4,4,5,5],"moves":[0,1,2,3,4,5,6,7,8,9,10,11]}
{"kind":"unlock","requestId":"purchase_nonce","deckId":"insects"}
```

Each ID is 8–80 `[A-Za-z0-9_-]` characters, generated once and reused for retries.
The board is locally shuffled before play: exactly two numeric occurrences of
every value `0` through `pairs-1`. The complete chronological transcript follows
the same 4000-move validation as ticket claims. The server checks deck ownership,
canonical arena access and purchase prices; it never accepts a supplied balance,
reward amount or crown count. Complete operations credit exactly 20 gems and
merge the best solo record. Unlock operations are permanent and charge once;
another device already owning the same deck causes no second charge. Neither
operation changes competitive crowns or arena thresholds.
Replay has a separate bounded budget of 6000 operations per profile and 7200 per
network address in ten minutes, so a large backlog does not consume the normal
profile/account request budget. A 429 response is retryable without losing work.

The response includes a fresh `profile` and `operation` receipt:
`{requestId,kind:"complete",reward:{gameId,gems:20,granted}}` or
`{requestId,kind:"unlock",deckId,unlocked,alreadyOwned}`. Receipts and game proof
hashes persist without the prepared-ticket TTL. A reused operation ID with a
different payload returns `IDEMPOTENCY_CONFLICT`; a game ID already submitted by
another profile returns `GAME_ALREADY_CLAIMED`. The ledger prevents repeated
credit even if the caller changes the operation ID for the same game.

The client persists an authoritative profile plus an ordered journal in one
snapshot, projects pending rewards and purchases immediately, and uploads in
order after reconnecting. It removes an acknowledged entry together with accepting
the returned profile, then reapplies remaining entries. This preserves work when
a response is lost or the app closes mid-sync. A second device's newer snapshot
can be merged without counting local rewards twice. Different simultaneous
offline purchases can exceed the shared balance: `INSUFFICIENT_GEMS` never
overdraws or records a failed operation. Keep that purchase pending, upload
independent completions, and retry when funded. A pending purchase's deck proofs
remain queued until that purchase succeeds.

## Completion and Bluetooth guest rewards

`POST /games/claims {ticketId,moves:[index,…],requestId,guestClaimToken?}` returns
`{profile,reward:{gameId,gems:20,granted}}`. `moves` is the complete chronological
list of accepted card indices for that game, including unsuccessful pairs, at
most 4000 moves. Do not include ignored taps during flips/locks. The server
simulates reveals/matches on the ticket board, rejects invalid indices, repeated
selected/matched cards, unfinished games and extra moves after completion.
No client-supplied balance, `+20` amount, score or finished flag is trusted.

Once a profile has the reward for this game, another valid claim cannot add gems.
A new request ID returns `granted:false`; an identical idempotent retry may return
the original `granted:true` result, while the balance is still credited once.
Use request IDs/game IDs to deduplicate any client reward animation.

Bluetooth tickets additionally contain `guestClaimToken`, a per-game capability.
Share **only ticket ID and this capability** with the guest while playing; never
profile tokens or recovery codes, and never board/seed before the game finishes.
After completion, the host sends the complete accepted-move transcript to the
guest. The guest queues its claim under its own profile after reconnecting. A
valid capability permits **one other profile**, distinct from the ticket owner,
to claim the same 20-gem completion reward. The guest need not own the deck. The
owner and guest each earn at most once; another guest is rejected. Deleting a
guest profile does not make that guest slot available again.

Only a hash of the guest capability is stored in SQLite. To make ticket issuance
idempotent without persisting plaintext capabilities, it is derived by HMAC-SHA256
from the random ticket ID and a private 256-bit server key stored mode 0600 next
to the database. Preserve this key with database backups. An expired ticket is
not claimable (410 `TICKET_EXPIRED`).

Offline transcript validation proves consistency and prevents replay/double
credit; it **cannot prove honest human play or prevent a modified client/bot from
solving a known offline board**. These are nontransferable game-only gems, with no
cash value. The quota bounds preparation; this is not competitive anti-cheat.

## Authoritative online games

WebSocket `/ws` remains protocol 1. `create`/`join` accept optional `profileToken`.
The server validates it and privately binds that player to the profile. It never
relays the token/profile credentials. Existing unauthenticated clients can still
host/join free decks; previous app versions support their original three themes.
A host selecting a paid deck must own it;
guests can join without ownership. Rematch checks host ownership again.
Every new client sends `supportedDecks` on WebSocket create/join/resume, with at
most 64 unique known canonical deck IDs. Omission means the original three themes.
The server rejects unsupported room themes with `UPDATE_REQUIRED` before any
seat/session mutation or snapshot; malformed capabilities produce
`INVALID_CAPABILITIES`. A guest owning no paid decks can still advertise the deck
IDs it knows how to render. Capabilities describe rendering support, not ownership.

State includes `roundId`, a new random ID for each actual round/rematch. The
public `rewards` map contains `{playerId:{gems:20,granted:true}}` receipts only for
profiles actually credited in that round, and resets to `{}` on a rematch. It
contains no profile IDs, tokens or balances. Use this receipt for result text,
presented after the final flip, rather than a balance delta that another device
could have changed. Replayed state/restarts cannot credit again.
The authoritative server engine enforces turns/reveals/mismatch timing. Only
`finishReason:"completed"` credits 20 to each distinct attached profile. A
forfeit, disconnect, waiting room or duplicate completion event pays nothing.
Clients refresh `GET /profile` after a completed round; no online claim endpoint
or offline ticket is required. Same-profile players cannot double the reward.
Restart recovers a persisted completed round before room expiry and ledger
uniqueness prevents repeat payment. Old clients without a profile earn no wallet
reward; upgrading does not retroactively pay their old games.
If wallet storage temporarily fails, the finished board is still broadcast and
the same reward is retried after 5 seconds. The room stays available past its TTL
while payment is pending; rematch returns `REWARD_PENDING` until resolution.
Restore isolates reward-hook failures per room, so unrelated rooms still load.

Ranked rooms additionally require `matchType:"ranked"`, the current `arenaId`
and features `ranked-v1` and `ranked-attempts-v1`. Three distinct decks from the arena's free
and either profile's owned collections are drawn once at match start. The three
12-pair rounds use identical layouts on independent, private player boards.
Each second card revealed counts one attempt, including mismatches. Both players
complete each board; the lower sum of attempts across all three rounds wins,
and equal totals draw. A completed match settles +20 crowns for a win, −20 for a loss
(minimum zero), zero for a draw. `peakCrowns` never decreases. Exactly 20 gems
are awarded to each profile only after all three rounds complete. Forfeit
settles crowns without gems; simultaneous expired disconnects and deleted
profiles cancel without rewards. Atomic `ranked_matches` receipts keyed by
`matchId` make both profiles' crown/gem settlement idempotent across retries and
restarts. Receipts expose only player IDs, gems, `granted` and `crownsDelta`.
Only one ranked match may be active per profile; no client endpoint sets crowns.
The complete wire contract is in [server protocol](../server/PROTOCOL.md).

New clients advertise `lobby-v1`: both connected players confirm readiness before
the match starts. A guest leaving this waiting lobby frees the second seat while
preserving the host's code; the host leaving closes it. These actions have no
crown or gem settlement. A disconnected guest can resume within 90 seconds before
the seat is freed automatically. Once play starts, the forfeit rules apply.

## Persistence and request limits

Requires Node >=22.13 (`node:sqlite`; experimental notice on Node22) or Node24.
One server process/writer, persistent `DATA_DIR/economy.sqlite`, WAL,
foreign-key cascades, `synchronous=FULL`, and `BEGIN IMMEDIATE` transactions for
wallet/unlock/claim/recovery changes. Back up the SQLite database consistently
(including WAL via SQLite backup or a stopped process) and capability key; do not
copy only a live `.sqlite` file. Sensitive files remain outside Git and logs.

REST JSON body limit 64 KiB; body read timeout 10s; allowed web origins match the
WebSocket allowlist. Tokens go in Authorization, never query strings. General
limit 240 requests/IP/10min, guest creation 10/IP/24h, recovery attempts20/IP/10min.
Native clients without Origin are accepted. Behind Caddy, enable TRUST_PROXY only
when the backend is reachable exclusively through the trusted proxy.

Do not retry a failed mutation with a new ID. On 401 `INVALID_TOKEN`, retain
recoverable local data and offer restore; do not silently replace a funded guest.
On 401 `PROFILE_DELETED`, erase the matching profile's local cache, recovery and
pending proofs. Hash-only deleted-session markers allow this distinction for 31
days; after expiry the response is the conservative generic `INVALID_TOKEN`.
On transient 5xx/network failure, keep pending claims/tickets/unlocks and retry
with the original ID. Reconcile a fresh profile before updating visible balances.

## Optional Apple and Google accounts

See [account configuration](ACCOUNTS_SETUP.md) for provider credentials, platform
setup and release checks. Appearance choices are validated by the server:
avatars `fox,cat,dog,panda,owl,rocket,star,flower`; accents
`forest,ocean,cosmos,sunset,rose`. Legacy name-only updates preserve appearance.

| Method/path | Body or query | Result |
| --- | --- | --- |
| GET `/auth/providers` | `?platform=ios\|android\|web` | Public configured providers with public client IDs and catalog IDs; no secrets |
| POST `/auth/attempts` | `{provider,platform,operation,requestId}` | Session-bound `attemptId,nonce,state,expiresAt` and platform configuration; operation `login`, `link` or `reauth` |
| POST `/auth/exchange` | `{attemptId,idToken?,authorizationCode?,state?}` | Verified `confirmationId,action,profile,expiresAt`; no account mutation yet |
| POST `/auth/confirm` | `{confirmationId,confirmReplace:true,requestId}` | `{profile}` or `{token,profile}` when changing profiles |
| POST `/auth/reauth/recovery` | `{recoveryCode}` | Marks this session recently verified, only for its own recovery code |
| POST `/auth/callback/apple` | Provider `form_post` callback | Web postMessage or Android opaque handoff bound to the initiating attempt |
| POST `/auth/notifications/apple` | `{payload}` signed notification | Signature-verified provider revocation/deletion event |
| GET `/profile/identities` | — | `{identities:[{provider,createdAt}]}`; no issuer, subject or provider credentials |
| DELETE `/profile/identities/:provider` | `{}` | `{profile}` after guarded unlink |
| GET `/profile/sessions` | — | `{sessions:[{id,deviceName,current,createdAt,lastUsedAt}]}` |
| DELETE `/profile/sessions/:id` | `{}` | `{revoked:true,current}`; session must belong to the authenticated profile |

Attempts expire after ten minutes; confirmations after five minutes. Nonces and
state bind provider credentials to a specific action and source device session.
New identities attach to the current guest without new welcome grants or wallet
merges. Already-owned identities require explicit confirmation before switching.
Adding another provider to an existing account requires fresh verification;
email equality is never evidence for linking accounts. Account sessions expire
after 90 days, while guest sessions retain their existing lifetime.

Sensitive operations on linked accounts require verification within five minutes
(`REAUTH_REQUIRED`, HTTP403). Recovery rotation and profile deletion use this same
guard. An account must retain a provider or recovery code when unlinking its last
provider. Public recovery preview excludes linked-provider metadata; private
identity/session routes require a valid account session.

Apple refresh credentials, verification proofs and idempotent confirmation
results are encrypted using AES-256-GCM and a domain-separated key derived from
`economy-capability.key`, which remains outside SQLite. Deletion queues necessary
provider revocations atomically before removing the profile; encrypted outbox
credentials expire after at most 30 days. Notifications and daily Apple refresh
verification revoke affected sessions. Request bodies, identity subjects,
authorization codes and provider token responses must never be logged.
