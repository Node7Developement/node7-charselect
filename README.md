[README.md](https://github.com/user-attachments/files/30388169/README.md)
[README.md](https://github.com/user-attachments/files/30317247/README.md)
# node7-charselect





<img width="1920" height="1080" alt="characterselector" src="https://github.com/user-attachments/assets/fd9171ab-5a15-4a86-9195-160c0f3b1dc1" />



# node7-charselect

NODE7 RedM character selector with a western roster layout, no centre character preview, a native fade-only Play handoff, staged loading, and exact interior-safe last-location persistence.

## Requirements

- `oxmysql`
- `node7-core`
- optional but recommended: `node7-appearance` for character creation and saved appearance loading after selection

## Start order

```cfg
ensure ox_lib
ensure oxmysql
ensure node7-core
ensure node7-appearance
ensure node7-charselect
```

## Character selection

- Left-side character roster.
- Right-side character record and creation panel.
- Open centre scene with no preview ped.
- No saved-appearance preview queries.
- No Q/E rotation controls or preview lighting loop.
- The real player stays hidden and frozen until the selected character is ready.

## Native Play handoff

The final Play sequence uses only RedM screen fades:

1. Fade to black.
2. Load the selected core character.
3. Apply the correct player model.
4. Restore the exact persisted position.
5. Wait for collision and interior streaming.
6. Apply the saved appearance.
7. Fade back into gameplay.

There is no wake animation, scripted spawn camera, entity dissolve, or post-processing wake effect.

## Last-location persistence

- Existing characters always use their persisted last position.
- Saved XYZ, heading, interior ID, and room key are preserved.
- Persisted interior positions are never ground-snapped.
- Position is saved on interior changes, movement intervals, forced intervals, logout, and successful spawn.
- Logout writes the exact live position before unloading the character.

## Appearance-ready integration

For the fastest appearance handoff, emit this after the saved appearance has been fully applied:

```lua
TriggerEvent('node7-charselect:client:appearanceReady')
```

A compatible resource may also call:

```lua
exports['node7-charselect']:MarkAppearanceReady()
```

The selector continues after a bounded timeout if no ready event is emitted.

## Configuration

Edit these sections in `config.lua`:

- `Scene`
- `DefaultSpawn`
- `SpawnFlow`
- `LastLocation`
- `Locations`

## Notes

- Uses the `players` table through `node7-core`.
- No horse dependency.
- No `rsg-core`, `rsg-spawn`, or RSG runtime dependency.
- No selectable spawn towns; existing characters return to their exact last location.
- New characters use `DefaultSpawn` once and then persist normally.

## v1.6.0

- Removed the centre character preview ped and all preview network/database work.
- Kept the RSG-inspired western roster and record layout.
- Removed preview rotation controls, preview lighting, and saved preview appearance loading.
- Replaced the wake camera/post effect with a smooth native fade-only Play handoff.
- Kept staged loading, appearance-ready gating, watchdog recovery, location title cards, and interior-safe last-location persistence.

[README.md](https://github.com/user-attachments/files/30333246/README.md)

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
