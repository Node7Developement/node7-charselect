# node7-charselect

NODE7 character selector using the RedEMRP charselect format/assets with NODE7 player persistence.

## Flow

1. Player opens charselect.
2. Existing character: press Play.
3. New character: use the right-side Create Full Character panel.
4. Charselect loads the character through `node7-players`.
5. Charselect opens `direct spawn`.
6. Spawnselect returns the selected spawn to charselect.
7. Charselect spawns the ped, applies `node7-skins`, then loads clothing if available.

No SQL is owned by this resource. It uses `node7-players` for citizenid persistence.


V9 clean direct-spawn notes:
- spawnselect removed
- clothing handoff removed
- stable Rhodes character scene enabled
- no loading/preparing text
