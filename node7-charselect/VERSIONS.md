# Versions

## 5.1.0

- Preserved the exact RSG selector player, preview ped, heading, and camera placement.
- Added a two-stage spawn handoff so `node7-core` cannot overwrite the saved gameplay location with selector coordinates during login.
- Saves the exact gameplay position before logout and refuses to persist selector-stage coordinates.
- Repairs legacy character positions that were previously saved inside the selector scene.
- Added the native RedM loading screen plus a NODE7 fallback loading overlay while appearance and world collision load.
- Added a spawn collision wait before revealing and unfreezing the real player ped.
- Fully resets selected slot and loading state when charselect reopens, fixing the first-character reselect issue after logout.

## 5.0.0

- Rebased on the supplied RSG multicharacter interface.
- Restored the exact original RSG player staging, preview ped, heading, and camera coordinates.
- Restored a separate preview ped instead of moving the real player into the display position.
- Uses `node7-appearance:ApplySkin` on the hidden player and clones that completed appearance for preview.
- Added RedM-safe in-UI identity creation with visible text, validation feedback, check marks, and Male/Female buttons.
- Removed the charselect `ox_lib` dependency and all external identity dialogs.
