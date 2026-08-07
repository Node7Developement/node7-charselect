# Versions

## 5.3.0

- Rebuilt the selector into a true nested page stack instead of expanding every section beneath the roster.
- Added roster, selected-character, four-step creation, and delete-confirmation pages inside one side panel.
- Removed the selector scrollbar completely; only the current page is rendered.
- Added Arrow Up/Down navigation, Enter/Right confirmation, and Left/Escape/Backspace return behavior.
- Kept full mouse support and direct text entry.
- Increased selected-character contrast, type size, spacing, and value-card readability.
- Preserved the no-preview-ped flow, hidden real player, cinematic camera, last-location loading, and recipe integration.

## 5.2.0

- Rebuilt character selection as one nested left-side flow.
- Removed the separate character-information panel, creation popup, and deletion popup.
- Selecting a slot now reveals its details, creation form, or delete confirmation directly beneath the slot list.
- Removed all preview-ped creation, cloning, appearance application, scenarios, and selection callbacks.
- Kept the hidden selector player, cinematic camera, reliable last-location handoff, collision wait, and native loading transition.
- Removed remote icon and font dependencies from the NUI.
- Preserved NODE7 Core, NODE7 Appearance, and recipe integration.


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
