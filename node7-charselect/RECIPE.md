# Recipe Notes

Resource name: `node7-charselect`

Required resources before this:

```cfg
ensure node7-core
ensure node7-players
ensure node7-skins
```

Optional spawn selector before charselect:

```cfg
```

Then:

```cfg
ensure node7-charselect
```

No database import is required for this resource. Use `node7-players` for character persistence.

Charselect does not use a spawn selector. Play/create spawns directly at saved position or safe Valentine fallback.


V9 clean direct-spawn notes:
- spawnselect removed
- clothing handoff removed
- stable Rhodes character scene enabled
- no loading/preparing text
