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
ensure node7-spawnselect
```

Then:

```cfg
ensure node7-charselect
```

No database import is required for this resource. Use `node7-players` for character persistence.

Charselect does not hard-depend on `node7-spawnselect`. If the spawn selector is missing or times out, it uses the character saved position fallback.
