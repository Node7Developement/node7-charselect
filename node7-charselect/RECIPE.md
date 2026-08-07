# NODE7 Recipe Integration

Start order:

```cfg
ensure oxmysql
ensure node7-core
ensure node7-appearance
ensure node7-charselect
```

`node7-charselect` uses `node7-core` for character data and notifications, and `node7-appearance` only when saving or loading the actual playable character.

The selector uses one nested side panel and does not create a preview ped. It saves the current gameplay position before logout and keeps the loading transition active until the stored scene, collision, and appearance are ready.
