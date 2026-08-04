# node7-charselect

NODE7 character selection using the supplied RSG multicharacter interface and its original preview scene.

## Requirements

- `oxmysql`
- `node7-core`
- `node7-appearance`

The resource does **not** use `ox_lib` for character creation. Identity fields are entered directly in the existing character creation panel with text inputs and Male/Female buttons.

## Start order

```cfg
ensure oxmysql
ensure node7-core
ensure node7-appearance
ensure node7-charselect
```

## Flow

- Existing characters load their skin and clothing only through `node7-appearance`.
- The real player ped stays hidden at the original RSG staging coordinates.
- A separate cloned preview ped stays at the original RSG preview coordinates.
- New characters save a default male or female Node7 appearance and spawn at `Config.DefaultSpawn`.
- Players can then visit the normal clothing/appearance locations to customize.
- Existing characters are moved to their stored gameplay position before `node7-core` login completes, preventing the selector scene from becoming their saved location.
- A native RedM loading screen and NODE7 loading overlay remain visible until appearance and collision are ready.
- Logout saves the exact gameplay position before the player is moved back to charselect.
