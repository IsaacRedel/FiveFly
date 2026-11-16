# API contract

How the UIs (phone app and panel), the client and the server talk to each other. The contract test in `ui/src/__tests__/contract.test.ts` checks that every action listed here exists in every layer.

## Flow

```text
UI (React)                client (Lua)                     server (Lua)
fetchNui(action, payload) ─▶ RegisterNUICallback(action)
                             ├─ local actions (audio.*, app.ready, panel.close)
                             └─ TriggerServerEvent("fivefly:server:request", id, action, payload)
                                                              ─▶ Actions.Dispatch
                             ◀─ TriggerClientEvent("fivefly:client:response", id, envelope)
◀─ cb(envelope)
```

- The UI adds `_origin` (`"phone"` or `"panel"`) to every payload. The client strips it before forwarding.
- The server identifies the player from the event `source` only. Payloads never carry player identifiers that the server trusts.
- Requests time out on the client after 10 seconds with `server_timeout`.

## Envelope

```json
{ "ok": true, "data": {} }
```

```json
{ "ok": false, "error": "error_code" }
```

Every request goes through these checks, in order: action exists → database migrated → permission → per-action rate limit → player identity.

| Error | Meaning |
| --- | --- |
| `unknown_action` | The action is not registered on the server. |
| `database_not_ready` | Migrations have not finished (or failed: check the server console). |
| `permission_denied` | `Config.RequirePermission` is on and the player lacks `Config.Permission`. |
| `rate_limited` | The action was called again before its cooldown. |
| `identity_unavailable` | The framework has no character loaded for this player yet. |
| `internal_error` | The handler raised an error (logged on the server). |
| `server_timeout` | Client-side: no response within 10 seconds. |

Domain errors: `invalid_track`, `invalid_name`, `invalid_playlist`, `playlist_not_found`, `playlist_full`, `playlist_limit`, `invalid_share_code`, `invalid_cover`, `invalid_profile`, `profile_not_found`, `private_profile`, `empty_queue`, `nothing_playing`, `invalid_action`, `invalid_repeat`, `invalid_position`, `invalid_session`, `session_not_found`, `search_unavailable`, `search_parse_failed`, `search_not_configured`, `media_not_allowed`, `media_reupload_not_configured`, `media_download_failed`, `media_upload_failed`, `media_too_large`, `media_not_image`.

## Shared types

```ts
type Track = { videoId: string; streamUrl?: string; title: string; thumbnail: string; duration: string; author: string };

type Session = {
  queue: Track[];
  currentTrack: Track | null;
  currentIndex: number | null; // 1-based
  status: "idle" | "online" | "paused";
  repeat: "off" | "all" | "one";
  shuffle: boolean;
  playback: { position: number; startedAt: number; nonce: number }; // startedAt in seconds (os.time)
};

type Playlist = { id: number; name: string; trackCount: number; cover: string; shareCode: string; visibility: "public" | "private"; ownerUserId?: number; ownerName?: string };

type Profile = {
  userId: number; // internal FiveFly id, never a framework identifier
  name: string; bio: string; avatar: string;
  isPublic: boolean; showActivity: boolean; following: boolean;
  followerCount: number; followingCount: number;
  publicPlaylists: Playlist[];
};

type SharedSession = { source: number; userId?: number; host: string; output: string; currentTrack: Track; queueCount: number };
type Section = { id: string; title: string; description?: string; tracks: Track[] }; // the UI translates by id
```

Tracks sent by the client are validated with `FiveFly.Utils.NormalizeTrack`: invalid ids, non-http URLs and oversized fields are rejected or trimmed. Tracks that will be played (queues, spatial audio) also go through `NormalizeClientTrack`, which keeps a `streamUrl` only when it belongs to a station in `Config.Stations`.

## Client-only actions

### app.ready

Returns `{ identifier, name, locale, phoneAvailable, panelEnabled }`.

### audio.output.get / audio.output.set

`{ output: "private" | "prop" | "vehicle" | "off" }`. `vehicle` fails with `vehicle_missing` when the player has no current or last vehicle.

### audio.volume.set / audio.mute.set

`{ value: 0-100 }` and `{ muted: boolean }`. Local only; the speaker volume heard by others follows it through the sync events.

### panel.close

Closes the panel and releases NUI focus.

## Server actions

Rate limits come from `Config.RateLimits` (writes, playback, recommendations) and `Config.Search.CooldownMs`. `app.get-initial-state` uses a fixed 300 ms; other reads are not limited.

> Português: [docs/pt-BR/api-contract.md](pt-BR/api-contract.md)

### app.get-initial-state

Everything the UI needs on open: `{ locale, profile, playback: Session, library: { favorites, playlists, history, stations, sharedSessions, friendsListening, recommendations, smartPlaylists, followingProfiles } }`. The client adds `audio: { output, volume, muted }`.

### playback.state.get

Returns the current `Session`.

### playback.play

`{ track?: Track, queue?: Track[], startIndex?: number }` → `{ session }`. The queue keeps its order (trimmed to `Config.Playback.MaxQueueSize`) and playback starts at `track`; `startIndex` (1-based) only picks between duplicates, or is used when `track` is missing. A `track` absent from the queue is inserted first. The UI sends a window of up to 50 tracks around the chosen one. The play is recorded in the history.

### playback.transport

`{ action: "pause" | "resume" | "play" | "next" | "prev" | "stop", position?: number, reason?: "ended" }` → `{ session }`. A `next` without `reason = "ended"` counts as a skip in the statistics.

### playback.queue.set

`{ queue: Track[] }` → `{ session }`. The current track is kept (reinserted first if missing).

### playback.mode.set

`{ shuffle?: boolean, repeat?: "off" | "all" | "one" }` → `{ session }`.

### playback.seek

`{ position: number }` (seconds) → `{ session }`.

### playback.sessions.get

`{ sessions: SharedSession[] }`: players currently playing through a speaker or vehicle.

### playback.friends.get

`{ friends: SharedSession[] }`: shared sessions of followed profiles that allow showing activity.

### playback.sessions.join

`{ source: number }` → `{ session }`: copies the host's queue and position.

### music.search

`{ query: string }` → `{ results: Track[] }`. Queries shorter than `Config.Search.MinLength` return an empty list. Results are cached per provider for `Config.Search.CacheTtlSeconds`.

### music.stations.get

`{ stations: [{ id, name, description, cover, tracks: Track[] }] }` from `Config.Stations`.

### music.recommendations.get

`{ recommendations: Section[] }` with ids `history`, `time` and `artist`.

### library.favorites.get

`{ favorites: Track[] }`.

### library.favorites.toggle

`{ track: Track }` → `{ favorite: boolean, track }`.

### library.history.get

`{ history: Track[] }` (latest 50).

### library.history.clear

→ `{ cleared: true }`.

### library.smart-playlists.get

`{ playlists: Section[] }` with ids `most-played`, `most-skipped` and `most-liked` (server-wide).

### library.playlists.get

`{ playlists: Playlist[] }` owned by the player.

### library.playlists.create

`{ name: string }` → `{ playlist }`. Fails with `playlist_limit` above `Config.Library.MaxPlaylists`.

### library.playlists.import

`{ shareCode: string }` → `{ playlist }`: copies any playlist (public or private) whose share code the player knows.

### library.playlists.cover.set

`{ playlistId: number, cover: string }` → `{ updated: true, cover }`. The URL goes through the media rules and may be re-uploaded, so use the returned `cover`.

### library.playlists.visibility.set

`{ playlistId: number, visibility: "public" | "private" }` → `{ visibility }`.

### library.playlists.delete

`{ playlistId: number }` → `{ deleted: true }`.

### library.playlists.tracks.get

`{ playlistId: number }` → `{ tracks: Track[] }`.

### library.playlists.tracks.add

`{ playlistId: number, track: Track }` → `{ added: true }`. Fails with `playlist_full` above `Config.Library.MaxTracksPerPlaylist`.

### library.playlists.tracks.remove

`{ playlistId: number, videoId: string }` → `{ removed: true }`.

### social.search

`{ query: string }` → `{ profiles: Profile[], playlists: Playlist[] }` (public only).

### social.profile.get

`{ userId?: number }` → `{ profile }`. Without `userId`, returns the player's own profile. Private profiles of other players fail with `private_profile`.

### social.profile.update

`{ bio?, avatar?, isPublic?, showActivity? }` → `{ profile }`. The display name always comes from the framework.

### social.follow.toggle

`{ userId: number }` → `{ following: boolean }`.

## Messages pushed to the UIs

Sent by `FiveFly.SendUiMessage(action, data)` to the lb-phone app (`SendCustomAppMessage`) and to the panel page (`SendNUIMessage` with `target = "ui"`).

| Action | Data |
| --- | --- |
| `playback.state` | `Session` after any playback change. |
| `playback.progress` | `{ videoId, position, duration }` about once per second while playing. |
| `playback.error` | `{ code, videoId }` from the audio engine. |
| `audio.state` | `{ output, volume?, muted?, reason? }`. |
| `library.changed` | `{ origin, action }` after a successful library/social mutation, so the other UI reloads. |

The panel also receives `{ target: "panel", action: "open" | "close" }`; the audio engine receives `{ target: "audio-engine", action: "engine.*", payload }`.

## Spatial audio events

| Event | Direction | Payload |
| --- | --- | --- |
| `fivefly:server:updateSource` | client → server | `{ track, status, playback, sourceType: "prop" \| "vehicle", sourceCoords, propNetId?, vehicleNetId?, range, volume, profile, vehicleClass, soundSystem }` |
| `fivefly:server:stopSource` | client → server | none |
| `fivefly:client:sourceAdded` | server → client | `sourceId, payload` |
| `fivefly:client:sourceUpdated` | server → client | `sourceId, payload` |
| `fivefly:client:sourceRemoved` | server → client | `sourceId` |
| `fivefly:client:forceStopPlayback` | server → client | `reason` |

The server caps `range` to the largest range in `Config.Range`, clamps `volume` to 0-100, uses the networked entity position when it exists and only accepts reported coordinates within `Config.Sync.MaxSourceDistance` of the player.
