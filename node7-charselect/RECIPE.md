# NODE7 Recipe Integration

Start order:

```cfg
ensure oxmysql
ensure node7-core
ensure node7-appearance
ensure node7-charselect
```

`node7-charselect` adds no `ox_lib` dependency. It uses `node7-core` for characters and notifications, and `node7-appearance` for saved skin/clothing.

The selector now saves last location before logout and keeps a loading screen visible until the stored scene and appearance are ready.
