# Contrato da API

Como as interfaces (app do celular e painel), o client e o servidor conversam. O teste de contrato em `ui/src/__tests__/contract.test.ts` confere se cada ação listada aqui existe em todas as camadas.

> English: [docs/api-contract.md](../api-contract.md)

## Fluxo

```text
UI (React)                client (Lua)                     servidor (Lua)
fetchNui(action, payload) ─▶ RegisterNUICallback(action)
                             ├─ ações locais (audio.*, app.ready, panel.close)
                             └─ TriggerServerEvent("fivefly:server:request", id, action, payload)
                                                              ─▶ Actions.Dispatch
                             ◀─ TriggerClientEvent("fivefly:client:response", id, envelope)
◀─ cb(envelope)
```

- A UI adiciona `_origin` (`"phone"` ou `"panel"`) a todo payload. O client remove esse campo antes de encaminhar.
- O servidor identifica o jogador só pelo `source` do evento. Nenhum identificador de jogador vindo no payload é considerado confiável.
- No client, as requisições expiram depois de 10 segundos com `server_timeout`.

## Envelope

```json
{ "ok": true, "data": {} }
```

```json
{ "ok": false, "error": "error_code" }
```

Toda requisição passa por estas verificações, nesta ordem: a ação existe → banco migrado → permissão → rate limit da ação → identidade do jogador.

| Erro | Significado |
| --- | --- |
| `unknown_action` | A ação não está registrada no servidor. |
| `database_not_ready` | As migrações não terminaram (ou falharam: veja o console do servidor). |
| `permission_denied` | `Config.RequirePermission` está ativo e o jogador não tem `Config.Permission`. |
| `rate_limited` | A ação foi chamada de novo antes do intervalo mínimo. |
| `identity_unavailable` | O framework ainda não carregou um personagem para o jogador. |
| `internal_error` | O handler gerou um erro (registrado no console do servidor). |
| `server_timeout` | No client: sem resposta em 10 segundos. |

Erros de domínio: `invalid_track`, `invalid_name`, `invalid_playlist`, `playlist_not_found`, `playlist_full`, `playlist_limit`, `invalid_share_code`, `invalid_cover`, `invalid_profile`, `profile_not_found`, `private_profile`, `empty_queue`, `nothing_playing`, `invalid_action`, `invalid_repeat`, `invalid_position`, `invalid_session`, `session_not_found`, `search_unavailable`, `search_parse_failed`, `search_not_configured`, `media_not_allowed`, `media_reupload_not_configured`, `media_download_failed`, `media_upload_failed`, `media_too_large`, `media_not_image`.

## Tipos compartilhados

```ts
type Track = { videoId: string; streamUrl?: string; title: string; thumbnail: string; duration: string; author: string };

type Session = {
  queue: Track[];
  currentTrack: Track | null;
  currentIndex: number | null; // começa em 1
  status: "idle" | "online" | "paused";
  repeat: "off" | "all" | "one";
  shuffle: boolean;
  playback: { position: number; startedAt: number; nonce: number }; // startedAt em segundos (os.time)
};

type Playlist = { id: number; name: string; trackCount: number; cover: string; shareCode: string; visibility: "public" | "private"; ownerUserId?: number; ownerName?: string };

type Profile = {
  userId: number; // id interno do FiveFly, nunca um identificador do framework
  name: string; bio: string; avatar: string;
  isPublic: boolean; showActivity: boolean; following: boolean;
  followerCount: number; followingCount: number;
  publicPlaylists: Playlist[];
};

type SharedSession = { source: number; userId?: number; host: string; output: string; currentTrack: Track; queueCount: number };
type Section = { id: string; title: string; description?: string; tracks: Track[] }; // a UI traduz pelo id
```

As faixas enviadas pelo client passam por `FiveFly.Utils.NormalizeTrack`: ids inválidos, URLs que não são http e campos grandes demais são rejeitados ou cortados. As faixas que vão tocar (filas e áudio espacial) também passam por `NormalizeClientTrack`, que só mantém um `streamUrl` quando ele pertence a uma rádio de `Config.Stations`.

## Ações só do client

### app.ready

Retorna `{ identifier, name, locale, phoneAvailable, panelEnabled }`.

### audio.output.get / audio.output.set

`{ output: "private" | "prop" | "vehicle" | "off" }`. `vehicle` falha com `vehicle_missing` quando o jogador não tem veículo atual nem último.

### audio.volume.set / audio.mute.set

`{ value: 0-100 }` e `{ muted: boolean }`. Só local; o volume da caixa de som ouvido pelos outros acompanha pelos eventos de sync.

### panel.close

Fecha o painel e libera o foco da NUI.

## Ações do servidor

Os rate limits vêm de `Config.RateLimits` (escritas, playback, recomendações) e de `Config.Search.CooldownMs`. `app.get-initial-state` usa 300 ms fixos; as demais leituras não têm limite.

### app.get-initial-state

Tudo o que a UI precisa ao abrir: `{ locale, appName, profile, playback: Session, library: { favorites, playlists, history, stations, sharedSessions, friendsListening, recommendations, smartPlaylists, followingProfiles } }`. `appName` é o `Config.Phone.Name`, exibido na interface. O client acrescenta `audio: { output, volume, muted }`.

### playback.state.get

Retorna a `Session` atual.

### playback.play

`{ track?: Track, queue?: Track[], startIndex?: number }` → `{ session }`. A fila mantém a ordem (cortada em `Config.Playback.MaxQueueSize`) e a reprodução começa em `track`; `startIndex` (começa em 1) só desempata entre faixas repetidas ou vale quando `track` não vem. Uma `track` que não está na fila é inserida no começo. A UI envia uma janela de até 50 faixas em volta da escolhida. A reprodução fica registrada no histórico.

### playback.transport

`{ action: "pause" | "resume" | "play" | "next" | "prev" | "stop", position?: number, reason?: "ended" }` → `{ session }`. Um `next` sem `reason = "ended"` conta como música pulada nas estatísticas.

### playback.queue.set

`{ queue: Track[] }` → `{ session }`. A faixa atual é mantida (reinserida no começo, se faltar).

### playback.mode.set

`{ shuffle?: boolean, repeat?: "off" | "all" | "one" }` → `{ session }`.

### playback.seek

`{ position: number }` (segundos) → `{ session }`.

### playback.sessions.get

`{ sessions: SharedSession[] }`: jogadores tocando numa caixa de som ou num veículo.

### playback.friends.get

`{ friends: SharedSession[] }`: sessões compartilhadas de perfis seguidos que permitem mostrar atividade.

### playback.sessions.join

`{ source: number }` → `{ session }`: copia a fila e a posição do anfitrião.

### music.search

`{ query: string }` → `{ results: Track[] }`. Buscas menores que `Config.Search.MinLength` retornam lista vazia. Os resultados ficam em cache por provider durante `Config.Search.CacheTtlSeconds`.

### music.stations.get

`{ stations: [{ id, name, description, cover, tracks: Track[] }] }`, a partir de `Config.Stations`.

### music.recommendations.get

`{ recommendations: Section[] }` com os ids `history`, `time` e `artist`.

### library.favorites.get

`{ favorites: Track[] }`.

### library.favorites.toggle

`{ track: Track }` → `{ favorite: boolean, track }`.

### library.history.get

`{ history: Track[] }` (as 50 mais recentes).

### library.history.clear

→ `{ cleared: true }`.

### library.smart-playlists.get

`{ playlists: Section[] }` com os ids `most-played`, `most-skipped` e `most-liked` (do servidor inteiro).

### library.playlists.get

`{ playlists: Playlist[] }` do jogador.

### library.playlists.create

`{ name: string }` → `{ playlist }`. Falha com `playlist_limit` acima de `Config.Library.MaxPlaylists`.

### library.playlists.import

`{ shareCode: string }` → `{ playlist }`: copia qualquer playlist (pública ou privada) cujo código o jogador saiba.

### library.playlists.cover.set

`{ playlistId: number, cover: string }` → `{ updated: true, cover }`. A URL passa pelas regras de mídia e pode ser reenviada, então use o `cover` retornado.

### library.playlists.visibility.set

`{ playlistId: number, visibility: "public" | "private" }` → `{ visibility }`.

### library.playlists.delete

`{ playlistId: number }` → `{ deleted: true }`.

### library.playlists.tracks.get

`{ playlistId: number }` → `{ tracks: Track[] }`.

### library.playlists.tracks.add

`{ playlistId: number, track: Track }` → `{ added: true }`. Falha com `playlist_full` acima de `Config.Library.MaxTracksPerPlaylist`.

### library.playlists.tracks.remove

`{ playlistId: number, videoId: string }` → `{ removed: true }`.

### social.search

`{ query: string }` → `{ profiles: Profile[], playlists: Playlist[] }` (só públicos).

### social.profile.get

`{ userId?: number }` → `{ profile }`. Sem `userId`, retorna o perfil do próprio jogador. Perfis privados de outros jogadores falham com `private_profile`.

### social.profile.update

`{ bio?, avatar?, isPublic?, showActivity? }` → `{ profile }`. O nome exibido sempre vem do framework.

### social.follow.toggle

`{ userId: number }` → `{ following: boolean }`.

## Mensagens enviadas às interfaces

Enviadas por `FiveFly.SendUiMessage(action, data)` ao app do lb-phone (`SendCustomAppMessage`) e à página do painel (`SendNUIMessage` com `target = "ui"`).

| Ação | Dados |
| --- | --- |
| `playback.state` | `Session` depois de qualquer mudança de reprodução. |
| `playback.progress` | `{ videoId, position, duration }`, cerca de uma vez por segundo durante a reprodução. |
| `playback.error` | `{ code, videoId }`, vindo do engine de áudio. |
| `audio.state` | `{ output, volume?, muted?, reason? }`. |
| `library.changed` | `{ origin, action }` depois de uma alteração bem-sucedida na biblioteca ou no social, para a outra interface recarregar. |

O painel também recebe `{ target: "panel", action: "open" | "close" }`; o engine de áudio recebe `{ target: "audio-engine", action: "engine.*", payload }`.

## Eventos do áudio espacial

| Evento | Direção | Payload |
| --- | --- | --- |
| `fivefly:server:updateSource` | client → servidor | `{ track, status, playback, sourceType: "prop" \| "vehicle", sourceCoords, propNetId?, vehicleNetId?, range, volume, profile, vehicleClass, soundSystem }` |
| `fivefly:server:stopSource` | client → servidor | nenhum |
| `fivefly:client:sourceAdded` | servidor → client | `sourceId, payload` |
| `fivefly:client:sourceUpdated` | servidor → client | `sourceId, payload` |
| `fivefly:client:sourceRemoved` | servidor → client | `sourceId` |
| `fivefly:client:forceStopPlayback` | servidor → client | `reason` |

O servidor limita `range` ao maior alcance de `Config.Range`, mantém `volume` entre 0 e 100, usa a posição da entidade em rede quando ela existe e só aceita coordenadas informadas a até `Config.Sync.MaxSourceDistance` do jogador. Para a caixa de som, um netId de entidade longe do jogador é ignorado.
