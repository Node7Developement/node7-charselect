# Versions

## 1.2.1

- Removed the spawn-selection screen and every selectable town destination.
- Existing characters now always load at their persisted last location.
- New characters use the configured fallback once, then persist that location.
- Server selection ignores client-provided spawn destinations.


## 1.2.0

- Rebuilt the character selector with a polished NODE7 interface.
- Removed the dedicated preview ped and all appearance-preview network traffic.
- Kept the player hidden during selection and only applies the real model after spawn.
- Preserved built-in spawn selection and node7-core persistence.

## 1.1.1

- Hardened Play/select server flow against core/database errors.
- Loads players through safe decoded DB data before registering with node7-core.
- Removed spawn selector dependency; built-in spawn only.

## 1.1.0

- Moved charselect persistence to the RSG-format `node7-core` player API.
- Removed hard `node7-players` dependency.
- Kept built-in spawn selection inside charselect.
