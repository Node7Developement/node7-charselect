# Versions

## 1.6.0

- Removed the centre preview ped, preview appearance query, rotation callbacks, and preview light loop.
- Preserved the RSG-inspired roster and character-record layout with an open centre scene.
- Replaced the wake camera and post effect with a native RedM fade-only Play handoff.
- Preserved exact interior-safe last-location persistence, staged loading, appearance-ready gating, and watchdog recovery.

## 1.5.0

- Added RSG-inspired live character preview presentation without any RSG dependencies.
- Added saved appearance preview through the existing `playerskins` data and `node7-appearance` preview exports.
- Added open-centre western UI, roster panel, record panel, and preview rotation controls.
- Replaced the gender dropdown with direct gender buttons.
- Preserved the v1.4 smooth spawn, interior streaming, autosave, and exact last-location fixes.

## 1.4.0

- Reworked the spawn handoff for smoother fade, camera interpolation, and delayed camera destruction.
- Preserves exact persisted coordinates inside buildings and no longer ground-snaps saved locations.
- Saves interior ID, room key, heading, and exact XYZ position.
- Added periodic movement-based last-location autosaving and immediate saves on interior changes.
- Replaced the logout save race with a synchronous core snapshot and authoritative final position write.
- Prevents node7-core's initial player save from replacing the persisted location with the character-selection scene.
- Added interior streaming preparation and a stable collision window before revealing the player.
- Added a smooth NUI transition fade instead of abruptly hiding the loading overlay.

## 1.3.0

- Added real loading stages for model, location, collision, core state, and appearance.
- Added full-screen NODE7 loading and waking-up presentation.
- Added a short native post-effect and scripted wake camera with interior-safe fallback.
- Added nearest-town location title cards and in-game clock display.
- Added appearance-ready events/export with a bounded timeout.
- Added live position saving before logout.
- Added a spawn watchdog that restores the player if loading stalls.

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
