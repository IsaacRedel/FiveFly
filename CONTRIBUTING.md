# Contributing

Thanks for helping! Bug reports, translations and pull requests are welcome.

## Reporting bugs

Open an issue with your framework and version, lb-phone version (if used), the steps to reproduce and the server/client console output. Use the bug report template.

## Development setup

- Lua 5.4 (`lua` and `luac` on your PATH) for the Lua tests.
- Node.js 22+ for the UI.
- A FiveM test server for anything involving natives, audio or NUI.

```sh
cd ui && npm ci && npm run dev   # http://127.0.0.1:3002/preview.html with sample data
```

## Before opening a pull request

```sh
lua tests/lua/run.lua                     # from the repository root
cd ui && npm run check                    # typecheck + tests + build
```

- Keep changes focused; one feature or fix per pull request.
- Validate on the server everything that touches money-like state, the database or other players: never trust values sent by the client.
- New NUI or server actions must be added to `docs/api-contract.md` (the contract test checks it).
- New UI strings go in both `ui/src/i18n/en.ts` and `ui/src/i18n/pt-BR.ts`.
- Do not commit `ui/dist`: releases build it.
- Describe what you tested in game, if anything. Automated tests do not cover audio or NUI focus.

## Translations

Copy `ui/src/i18n/en.ts` to a new file typed as `Messages`, translate the values and register it in `ui/src/i18n/index.ts`.

## Code style

- Lua: 4 spaces, `local` everything, early returns, `FiveFY.*` namespaces. Annotate shared types with LuaLS comments.
- TypeScript/React: functional components, state in `ui/src/state`, no new runtime dependencies without discussion.
- Keep NUI pages transparent outside their own panels (no `color-scheme: dark`, no `backdrop-filter` on full-screen wrappers).
