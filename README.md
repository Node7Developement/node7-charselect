[README.md](https://github.com/user-attachments/files/30317247/README.md)
# node7-charselect






![Uploading CHARSELECT.PNG…]()

NODE7 character selection resource using the uploaded RedEMRP charselect UI format and image assets while keeping NODE7 persistence through `node7-players`.

## Start order

```cfg
ensure node7-core
ensure node7-players
ensure node7-skins
# optional, only if installed:
ensure node7-spawnselect
ensure node7-charselect
```

Do not run `node7-multicharacter` at the same time.

## Spawn selector support

When `node7-spawnselect` is started, Play/Create/Finish Setup sends the loaded character into the spawn selector instead of spawning immediately.

Expected spawn selector callback event:

`node7-charselect:client:spawnSelected`

Payload can be any of these formats:

```lua
{ id = 'valentine' }
{ position = { x = -325.06, y = 773.62, z = 117.43, w = 286.0 } }
{ coords = { x = -325.06, y = 773.62, z = 117.43, heading = 286.0 } }
```

Cancel event:

`node7-charselect:client:spawnCancelled`

If `node7-spawnselect` is not started or never responds, charselect falls back to the saved last location so Play never freezes.

## Notes

- No SQL is owned by this resource.
- Characters are loaded/created through `node7-players`.
- Skin loads through `node7-skins` during final spawn.
- Clothing bridge tries started NODE7 clothing resources after spawn.
- RedEMRP UI format/images are preserved. Font files are not bundled.
