# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow [Semantic Versioning](https://semver.org/).

## [1.0.0] - Unreleased

First public release, rewritten from the private `mzm_CaliFY` resource.

### Added

- Desktop panel opened by command or key binding, sharing state with the phone app. lb-phone is now optional.
- Framework bridge for Qbox, QBCore, ESX, vRP and standalone.
- Official YouTube Data API search provider (`fivefy_youtube_key` convar), with scraping as a fallback.
- Automatic database migrations compatible with MySQL 8 and MariaDB.
- English and Brazilian Portuguese UI.
- Playlist limit (`Config.Library.MaxPlaylists`) is now enforced.
- Lua and UI test suites, CI and release workflows, browser demo.

### Changed

- Players are identified by a stable framework identifier mapped to an internal id (never the server id).
- Secrets moved from `config.lua` to server convars.
- Default speaker prop is the base-game `prop_boombox_01`.
- Playing a track from a list keeps the list order.
- Auto-advanced tracks are recorded in the history.

### Security

- Spatial audio range, volume and position reported by clients are capped and validated on the server, including speaker entity ids far from the player.
- Stream URLs sent by clients are only kept when they match a configured station, so a modified client cannot make nearby players load arbitrary URLs.
- Image URL validation rejects hosts with credentials or unusual characters.
- Playback sessions are cleared when a player disconnects.
