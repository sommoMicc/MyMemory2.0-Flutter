# MyMemory multiplayer protocol v1

Connect to `wss://sommomemory.sommomi.cc/ws`. Every frame is one JSON object.
Rooms support exactly two players. No account, email or advertising identifier is used.

## Client messages

| type | fields | behavior |
| --- | --- | --- |
| `create` | `name`, `pairs` (6, 8, 12 or 18), `theme` (`garden`, `cosmos`, `ocean`) | Creates room; save returned session locally. |
| `join` | `code`, `name` | Joins the second seat and starts play. Room codes are case insensitive. |
| `resume` | `code`, `token` | Restores a seat after reconnect or server restart; replaces previous socket. |
| `flip` | `index` (integer, zero based) | Reveals one card if permitted by server. |
| `rematch` | none | Votes to replay. Both connected players must vote. |
| `leave` | none | Leaves the room, forfeits active play, and invalidates this seat's token. |
| `ping` | none | Returns `pong` with server time. |

One active session per socket. Leave it before creating or joining another room.
Player names are trimmed and limited to 24 visible Unicode characters.

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
Card values are string IDs `"0"` through `String(pairs-1)`, mapped to the shared ordered illustrated collections by the client (garden = Animali, cosmos = Spazio, ocean = Oceano). Images are bundled on each device; only card IDs cross the network. Hidden values are **never sent**. Matched cards remain visible.
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
