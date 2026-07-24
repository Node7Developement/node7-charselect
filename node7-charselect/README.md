# node7-charselect

NODE7 polished character selector with built-in character creation and last-location-only spawning.

## Requirements

- `oxmysql`
- `node7-core`
- optional: `node7-appearance` for creator and saved appearance loading after spawn

## Start order

```cfg
ensure ox_lib
ensure oxmysql
ensure node7-core
ensure node7-appearance
ensure node7-charselect
```

## Notes

- Uses the `players` table through `node7-core`.
- Existing characters always spawn at their persisted last location.
- No horse dependency.
- No `player_horses` table use.
- No `rsg-core`, `rsg-spawn`, or `rsg-horses` runtime calls.
- New characters use `DefaultSpawn` once, then continue from their persisted last location.
- No preview ped is created or queried.
- The actual player model and saved appearance are applied only after character selection and spawn.

## v1.2.0

- Rebuilt the NUI with a polished NODE7 layout.
- Removed the preview ped, saved-preview queries, preview callbacks, and preview render loop.
- Preserved character persistence, deletion, creation, last location, and post-spawn appearance loading.
