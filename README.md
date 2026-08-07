[README.md](https://github.com/user-attachments/files/30808553/README.md)
# node7-charselect


<img width="1681" height="1070" alt="characterselectorrrrr" src="https://github.com/user-attachments/assets/cecfdbfa-6021-4d8c-a01b-6ea28f2daec3" />


NODE7 RedM character selection with a true nested side-panel flow, keyboard navigation, and no preview ped.

## Requirements

- `oxmysql`
- `node7-core`
- `node7-appearance`

## Start order

```cfg
ensure oxmysql
ensure node7-core
ensure node7-appearance
ensure node7-charselect
```

## Nested flow

- The roster is the root page. Opening a slot replaces it with that slot's nested page inside the same side panel.
- Existing characters open a readable detail page with Enter County, Delete Character, and Back actions.
- Empty slots open a four-page creation path: Name, Background, Gender, and Review.
- Only the current nested page is visible, so the interface never needs a scrollbar.
- Delete confirmation is its own nested page and returns to the selected character.
- Arrow Up and Arrow Down move selection. Enter or Arrow Right opens/confirms. Arrow Left, Escape, or Backspace returns when appropriate.
- Mouse selection remains available.
- No character preview ped is created, cloned, dressed, moved, or displayed.
- The real player ped remains hidden at the selector stage until a character is loaded.
- Existing characters spawn at their stored gameplay position after appearance and collision finish loading.
- New characters receive the configured default NODE7 appearance and spawn at `Config.DefaultSpawn`.
- The native RedM loading screen and NODE7 fallback overlay remain active during the final spawn handoff.
- Logout saves the gameplay position before returning to character selection.
