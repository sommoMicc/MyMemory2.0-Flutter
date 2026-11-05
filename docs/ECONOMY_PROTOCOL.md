# SommoMemory profiles and gems — API v1

Base URL: `https://sommomemory.sommomi.cc/api/v1`. JSON requests and responses;
`Authorization: Bearer <token>` on authenticated routes. No cookies, email,
passwords, third-party login, money, purchases or transfers. All responses use
`Cache-Control: no-store`. Error shape: `{ "error": { "code": "…", "message": "…" } }`.

## Catalog and profile

`GET /catalog` is public and returns `decks` and `rules`. Stable deck IDs/prices:
`garden:0`, `cosmos:0`, `ocean:0`, `paola:0`, `food:200`, `sports:300`, `travel:400`.
The first four are always owned, including by existing profiles with no wallet
charge or new welcome grant. Unlocks are permanent within a profile.
`paola` is the text-based Paola collection: string IDs 0–17 map in order to
PA, PE, PI, PO, PU, LA, LE, LI, LO, LU, MA, ME, MI, MO, MU, SA, SE, SI.

Profile JSON is `{id,displayName,activated,recoveryVersion,gems,ownedDecks,revision}`. Display name
may be empty; limit 24 Unicode characters. Treat the server snapshot as
authoritative and ignore lower revisions for the **same profile ID**. Replacing
the profile changes the ID/revision scope and must clear profile-specific caches.

| Method/path | Body | Response |
| --- | --- | --- |
| POST `/profiles` (public) | `{}` | 201 `{token,profile}`: anonymous guest, 100 welcome gems once |
| GET `/profile` | — | `{profile}` |
| PATCH `/profile` | `{displayName}` | `{profile}` |
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
Unknown deck: 400 `INVALID_DECK`.

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

First use without a network-issued ticket can still play practice games with
already-owned/free decks; it cannot earn verified gems. Cache owned decks and
unused tickets for offline play, and queue completed transcripts durably.

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
most 10 unique known canonical deck IDs. Omission means the original three themes.
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
On transient 5xx/network failure, keep pending claims/tickets/unlocks and retry
with the original ID. Reconcile a fresh profile before updating visible balances.
