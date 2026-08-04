# Versions

## 5.0.0

- Rebased on the supplied RSG multicharacter interface.
- Restored the exact original RSG player staging, preview ped, heading, and camera coordinates.
- Restored a separate preview ped instead of moving the real player into the display position.
- Uses `node7-appearance:ApplySkin` on the hidden player and clones that completed appearance for preview.
- Added RedM-safe in-UI identity creation with visible text, validation feedback, check marks, and Male/Female buttons.
- Removed the charselect `ox_lib` dependency and all external identity dialogs.
