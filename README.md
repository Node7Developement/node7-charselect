[README.md](https://github.com/user-attachments/files/30317247/README.md)
# node7-charselect






<img width="1920" height="1080" alt="CHARSELECT" src="https://github.com/user-attachments/assets/11360237-fa02-477c-85a1-078fdcda31c3" />


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

- Characters are loaded/created through `node7-players`.
- Skin loads through `node7-skins` during final spawn.
- Clothing bridge tries started NODE7 clothing resources after spawn.
- RedEMRP UI format/images are preserved. Font files are not bundled.
