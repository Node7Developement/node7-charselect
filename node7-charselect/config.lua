Node7CharselectConfig = {}

Node7CharselectConfig.Debug = false
Node7CharselectConfig.DefaultNumberOfCharacters = 4
Node7CharselectConfig.AllowDelete = true
Node7CharselectConfig.RequireLastCharacterBeforeDelete = true

-- No horses. This resource only owns character selection and spawn placement.
Node7CharselectConfig.StarterHorse = false
Node7CharselectConfig.StarterItems = false

Node7CharselectConfig.Scene = {
    player = { x = -562.91, y = -3776.25, z = 237.63, w = 90.0 },
    lightOffset = { x = 0.0, y = 0.0, z = 1.0 },
    introCam = {
        x = -555.925, y = -3778.709, z = 238.597,
        rx = -20.0, ry = 0.0, rz = 83.0,
        fov = 30.0
    },
    fixedCam = {
        x = -561.206, y = -3776.224, z = 239.597,
        rx = -20.0, ry = 0.0, rz = 270.0,
        fov = 30.0
    }
}

-- Existing characters always use their persisted last position.
-- A brand-new character uses this fallback once, then that position is persisted.
Node7CharselectConfig.DefaultSpawn = { x = -325.06, y = 773.62, z = 117.43, w = 286.0 }

Node7CharselectConfig.AppearanceResource = 'node7-appearance'
Node7CharselectConfig.SkinsResource = 'node7-skins'
Node7CharselectConfig.OpenAppearanceForNewCharacters = true
Node7CharselectConfig.LoadSavedSkinOnSpawn = true
Node7CharselectConfig.FadeInMs = 800
Node7CharselectConfig.FadeOutMs = 350
