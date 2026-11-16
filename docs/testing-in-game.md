# In-game test checklist

> Português: [docs/pt-BR/testing-in-game.md](pt-BR/testing-in-game.md)

Automated tests (`lua tests/lua/run.lua` and `npm test` in `ui/`) cover pure logic with stubbed natives. They do not prove that audio, NUI focus or the phone integration work in FiveM. Run this checklist on a test server before each release, ideally with two players.

## Start

- [ ] `ensure oxmysql`, your framework, `lb-phone` (optional) and `fivefly`, in this order.
- [ ] The console shows `framework: <name>` and no errors. On first start, `applying database migration 1`.
- [ ] Restarting `fivefly` while players are online does not leave a grey or black layer on screen.

## Phone app (lb-phone)

- [ ] The FiveFly app appears and opens.
- [ ] Search returns results; playing a track starts audio.
- [ ] Pause, resume, seek, next, previous, shuffle and repeat work.
- [ ] Favorites, playlists (create, add, remove, cover, visibility, delete), import by code.
- [ ] Profile edit (gallery and URL avatar), follow another player, public playlists on their profile.
- [ ] Dropping the phone item stops music started from the phone (`Config.Phone.StopWithoutPhoneItem`).

## Panel

- [ ] `/fivefly` (or the key binding) opens it; Esc and the close button close it and release the mouse.
- [ ] It controls the same playback as the phone, and changes in one show up in the other.
- [ ] Works on a server **without** lb-phone.
- [ ] Opening is blocked while dead (`Config.Panel.CanOpen`), and the panel closes when the player dies.
- [ ] No background outside the panel window at common resolutions (1366x768, 1920x1080, 2560x1440).

## Outputs and spatial audio (two players)

- [ ] Private: only the owner hears it.
- [ ] Speaker: the prop appears in hand, the second player hears it fading with distance and stops hearing it outside the range.
- [ ] Vehicle: works in the current vehicle; a sound-system trailer becomes the source when hitched; playback stops when the owner walks more than `ownerMaxDistance` away.
- [ ] Joining a shared session plays the same track at the same position.

## Data

- [ ] Reconnect: favorites, playlists, history and profile are still there.
- [ ] Multicharacter frameworks: switching characters shows a different library.
