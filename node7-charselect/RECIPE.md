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

## Appearance completion

For the fastest saved-appearance handoff, emit this after appearance application finishes:

```lua
TriggerEvent('node7-charselect:client:appearanceReady')
```

The selector has a bounded timeout and will recover rather than remaining on a black screen.

## Selection presentation

The selector intentionally does not create a preview ped. Play uses a native fade-only handoff with no wake animation, scripted spawn camera, entity dissolve, or post effect.
