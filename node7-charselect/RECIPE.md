# NODE7 Charselect Recipe

Start order:

```cfg
ensure ox_lib
ensure oxmysql
ensure node7-core
ensure node7-appearance
ensure node7-charselect
```

`node7-charselect` uses the `players` table owned by `node7-core`.

Do not run these with this resource:

```cfg
# ensure rsg-multicharacter
# ensure rsg-spawn
# ensure node7-multicharacter
# ensure node7-spawnselect
```
