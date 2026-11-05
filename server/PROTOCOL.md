# SommoMemory multiplayer protocol v1

Connect to `wss://sommomemory.sommomi.cc/ws`. Every frame is one JSON object.
Rooms support exactly two players. No email or advertising identifier is used.
An optional opaque profile token associates completion gems with a synced wallet;
room sessions and profile sessions are independent credentials.

## Client messages

| type | fields | behavior |
| --- | --- | --- |
| `create` | `name`, `pairs` (6, 8, 12 or 18), `theme` (`garden`, `cosmos`, `ocean`, `paola`, `food`, `sports`, `travel`), optional `profileToken`, `supportedDecks` | Creates room; host must own paid deck. Save returned room session locally. |
| `join` | `code`, `name`, optional `profileToken`, `supportedDecks` | Joins the second seat and starts play. Guest need not own the deck. Room codes are case insensitive. |
| `resume` | `code`, `token`, optional `supportedDecks` | Restores a seat after reconnect or server restart; replaces previous socket. |
| `flip` | `index` (integer, zero based) | Reveals one card if permitted by server. |
| `rematch` | none | Votes to replay. Both connected players must vote. |
| `leave` | none | Leaves the room, forfeits active play, and invalidates this seat's token. |
| `ping` | none | Returns `pong` with server time. |

One active session per socket. Leave it before creating or joining another room.
Player names are trimmed and limited to 24 visible Unicode characters.
New clients send `supportedDecks` on **every create, join and resume**: an array
of at most 10 distinct canonical deck IDs from the supported theme list. Unknown
IDs, duplicates, nonstrings and nonarrays yield `INVALID_CAPABILITIES`. Omission
means exactly the legacy three decks `garden`, `cosmos`, `ocean`. An unavailable
room theme yields `UPDATE_REQUIRED` with **Aggiorna SommoMemory per giocare con
questa collezione.**, before occupying a seat, reconnecting a player, replacing
an existing socket or sending any state. Updated clients send all seven known
IDs; old free-deck rooms continue to accept old and new clients. No protocol
version bump is needed.

## Server messages

`session`: `{type:"session",code,token,playerId}`. The token is a bearer secret;
retain it on the device, never put it in links or logs. `resume` echoes the same token.
This is followed by `state`.

`state`:

```json
{
  "type": "state",
  "code": "ABC234",
  "pairs": 8,
  "theme": "garden",
  "roundId": "random-round-id",
  "rewards": {},
  "phase": "playing",
  "turn": "player-id",
  "cards": [null,"0",null,"0"],
  "matched": [1,3],
  "selected": [],
  "players": [{"id":"player-id","name":"Michele","score":1,"connected":true}],
  "revision": 8,
  "rematch": [],
  "lockedUntil": null,
  "winnerId": null,
  "finishReason": null
}
```

The sample `cards` is shortened; its actual length is `pairs * 2`.
Card values are string IDs `"0"` through `String(pairs-1)`, mapped to shared ordered collections by the client (garden = Animali, cosmos = Spazio, ocean = Oceano, paola = Paola, food = Cibo, sports = Sport, travel = Viaggi). Images or syllable text are bundled on each device; only card IDs cross the network. Hidden values are **never sent**. Matched cards remain visible.
Paola is free and maps IDs 0–17 to PA, PE, PI, PO, PU, LA, LE, LI, LO, LU, MA,
ME, MI, MO, MU, SA, SE, SI, in this order; no image download is required.
`selected` contains exposed indices that have not yet matched. A mismatch remains
visible for 900ms; `lockedUntil` is the server Unix time in milliseconds. After
that time the server hides the pair, changes turn, and broadcasts a new state.
The client presents immutable snapshots independently of authority. Card targets
animate first; scores, matched styling and results appear only after opening
flips complete, and turn changes wait for closing flips. Table input stays locked
through both opening and closing animations, even after the engine unlocks.
Remote card changes are queued in order; repeated unchanged snapshots are
ignored. Reduced motion settles without an artificial animation delay. Input
still checks the latest authoritative turn and lock, so presentation cannot
authorize a stale move. A successful match retains the turn. `revision` increases
on every mutation.

`phase` is `waiting`, `playing` or `finished`. `turn` is null outside active play.
`winnerId` is null on draws and before completion. `finishReason` is `completed`,
`forfeit` or null. A disconnected player has 90 seconds to resume. Play pauses
while either player is disconnected. If the grace period expires, the opponent
wins by forfeit; if both grace periods have expired the room is discarded.
Explicit leave immediately forfeits active play and disables rematch.

`rematch` contains player IDs that voted for a rematch. When both connected players
vote, scores reset and a freshly shuffled board starts, with the starter alternating.
`roundId` changes each round, while `code` remains the room code. `rewards` resets
to `{}` and, on a completed round, contains only actual wallet receipts:
`{ "player-id": { "gems":20, "granted":true } }`. No profile IDs or balances are
public. A profile receives at most one reward per round, even if both seats use it.
Forfeits earn nothing. Refresh the authenticated REST profile after completion;
use the receipt for that round's result UI rather than a wallet-balance delta.
Ledger retries/restarts cannot double-credit. During a temporary wallet-storage
failure the final board is still published; the receipt is retried and a rematch
returns `REWARD_PENDING` until resolved. Existing unprofiled free-deck clients
remain compatible. See [ECONOMY_PROTOCOL.md](../docs/ECONOMY_PROTOCOL.md).

`error`: `{type:"error",code,message}`. `message` is suitable for display in Italian.
`left`: `{type:"left"}` confirms departure. `pong`: `{type:"pong",time}`.

## Operational behavior

- `GET /healthz`: JSON liveness, protocol version and room count (no room data).
- Static Flutter web assets are served from `WEB_DIR` (SPA fallback).
- `GET /privacy` and `/support`: static public information pages.
- Rooms persist atomically to `DATA_DIR/rooms.json` (default `./data`). Tokens are
  stored only as SHA-256 hashes. On restart players become disconnected and may resume.
- Rooms expire after 24 hours of inactivity; default limit is 500 concurrent rooms.
- Messages are limited to 4KiB, 30 messages per 10 seconds per connection, and
  32 concurrent connections per network address. Server heartbeats clean up dead sockets.
- Service is a **single instance**; persistent storage must survive container replacement.
  A future multi-instance deployment needs shared transactional storage and pub/sub.
