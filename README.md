Parties for a Godot 4 game: people who play together. A party is tracked from the lobby to the game server, its members join that server together, and a server can be booked for a party and actually keep the seats for them. It works with the TMC website's party system. It needs only [dot-core](https://github.com/gamespice-platform/core). Part of TMC's open source **Gamespice** collection (MIT licence).

> Built with Claude Code. Every addon has a headless test suite and the suites pass, but little of this has met real players yet. Please report rough edges.

## Install

Copy `addons/dot_party/` and dot-core's `addons/dot_core/` into your project and enable dot-party under **Project > Project Settings > Plugins**. dot-auth's client and dot-server's admission check are used when present but never required.

## Backends

A game holds one backend and does not need to know which.

| Backend | What it talks to |
| --- | --- |
| `DotPartyBackendApp` | The website, as the signed-in player. |
| `DotPartyBackendLocal` | The website's rules run inside your process, for a LAN, an offline build and tests. |

A refusal carries the website's own reason key (such as `party.join.deny.full` or `party.reserve.deny.window`) in `DotError.detail`, from either backend. The website translates those keys into nine languages, and [dot-locale](https://github.com/gamespice-platform/locale) can show them in the player's.

## Joining a server together

The party's ready round is how it moves. The host picks a server, everybody is told where to connect, and the round starts when everyone is ready, or, if the party set a threshold, when that share is ready and a countdown runs out.

`DotPartyClient` polls the party (fast during a ready round, slower otherwise), sends a heartbeat so the website does not drop the player, and turns each new snapshot into events: someone joined, someone was kicked, the stage changed. When a ready round opens it asks your game to connect once, reports that the player arrived, and does it again the next time the party moves.

```gdscript
var party := DotPartyClient.new()
var app := DotPartyBackendApp.new()
app.client = auth          # dot-auth's DotAuthClient: it holds the token and refreshes it
party.backend = app
party.user_id = auth.identity().uid.trim_prefix("backbone:")
party.connect_fn = func(url: String, _info: Dictionary) -> DotResult:
    return await game.connect_to(url)
add_child(party)

party.member_joined.connect(func(m): hud.toast("%s joined" % m.display_name))
party.left_party.connect(func(_id, why): if why == "kicked": hud.toast("You were removed from the party"))
```

## Booking a server

A party can book a server for a while if the server's owner allows it. `DotPartyReservations` is the game server's half. It learns the booking (from the website, a local hub or the owner at the console) and answers the admission question dot-server already asks on every join.

| Booking | What the server does |
| --- | --- |
| Private | Admits the party and nobody else, apart from people the owner lets through (usually admins). |
| Public | Stays open, but holds a seat for every member who has not arrived yet, for the first `seat_hold_sec` seconds. |

It chains onto whatever ban list is already installed, so a banned player is still banned on a booked server. If the website cannot be reached the booking stays in force, because an outage must not open a private server.

The owner's booking terms are `DotPartyReservePolicy`, using the same rules as the website:

| Setting | Default | What it does |
| --- | --- | --- |
| `enabled` | false | Whether bookings are allowed at all. |
| `lobbies` | public only | Which shapes may be booked (public, private or both). |
| `empty_only` | true | Only book a server with nobody on it. |
| `max_minutes` | 0 | Longest booking the owner allows. 0 = the site's limit. A longer request is shortened, not refused. |
| `site_max_minutes` | 180 | The website's own limit. |
| `auto_approve` | true | Accept bookings without the owner's approval. |
| `cooldown_minutes` | 15 | Wait between bookings. |
| `days`, `from_minute`, `to_minute` | all days, 0, 0 | Allowed days and booking window in UTC. A window can cross midnight. |

## Tracking a party on a game server

`DotPartyServer` tells the website who from which party is on the server, so play time, rounds and scores are recorded. It sends a full roster report every `state_report_sec` seconds, exact join and leave events, and round results with places.

A joining client names its party. The server fetches that party's roster and checks the player is on it before tracking anything, so claiming a party you are not in does nothing.

`groups(uids)` returns connected players grouped by party, for a team balancer that should keep parties together.

## Settings

`DotPartyConfig` is layered like every Gamespice config: defaults, JSON file, `DOT_PARTY_*` environment, `--party-*` command line. Several values mirror the website's own numbers. A client that heartbeats less often than the site expects is dropped from its own party, so `heartbeat_sec` must stay under 150.

| Setting | Default | What it does |
| --- | --- | --- |
| `poll_sec` | 22.5 | Seconds between polls in a lobby. |
| `ready_poll_sec` | 1.5 | Seconds between polls during a ready round. Must not exceed `poll_sec`. |
| `heartbeat_sec` | 45.0 | Seconds between heartbeats. The site drops a silent member after 150. |
| `state_report_sec` | 15.0 | Seconds between full roster reports. The site asks for 10 to 30. |
| `roster_refresh_sec` | 60.0 | Seconds between re-reading the rosters of the parties on this server. |
| `reservation_sync_sec` | 30.0 | Seconds between asking whether this server is booked. |
| `seat_hold_sec` | 180.0 | Seconds after a public booking starts that seats are held for members who have not arrived. 0 = no hold. |
| `reservation_warn_sec` | 300.0 | Seconds before a booking ends to warn the people on the server. |
| `release_when_empty_sec` | 600.0 | Seconds a booked server may sit with none of its party before the booking is released early. 0 = never. |

## The website routes

The server half uses the website's integration routes under `/api/integration/v1/party/`, and the player half uses `/api/app/v1/party/`. [docs/backbone-contract.md](docs/backbone-contract.md) lists every route. A website without them makes `DotPartyBackendApp` fail each call with a message that says so, and `DotPartyBackendLocal` gives a game the same behaviour offline.

## More

[docs/design.md](docs/design.md) explains the choices and [docs/history.md](docs/history.md) lists bugs worth recognising if they return.

## Licence

MIT. See [LICENSE](LICENSE).
