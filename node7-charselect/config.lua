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


-- RSG-inspired open-centre presentation adapted for NODE7. The real player is
-- hidden during selection and no preview ped is created or rendered.


-- Existing characters always use their persisted last position.
-- A brand-new character uses this fallback once, then that position is persisted.
Node7CharselectConfig.DefaultSpawn = { x = -325.06, y = 773.62, z = 117.43, w = 286.0 }

Node7CharselectConfig.AppearanceResource = 'node7-appearance'
Node7CharselectConfig.SkinsResource = 'node7-skins'
Node7CharselectConfig.OpenAppearanceForNewCharacters = true
Node7CharselectConfig.LoadSavedSkinOnSpawn = true
Node7CharselectConfig.FadeInMs = 850
Node7CharselectConfig.FadeOutMs = 350


-- Polished loading / waking flow. All waits are bounded by the watchdog so the
-- player is never intentionally left on a permanent black screen.
Node7CharselectConfig.SpawnFlow = {
    Enabled = true,
    MaxSpawnMs = 30000,
    CollisionTimeoutMs = 9000,
    WorldStableMs = 250,
    AppearanceTimeoutMs = 4500,
    AppearanceMinimumWaitMs = 500,
    LocationCardMs = 4200,
    LogoutTimeoutMs = 12000,
    NativeBlackHoldMs = 150
}


-- Final spawn handoff uses only native RedM screen fades. No scripted camera,
-- ped animation, entity dissolve, or post-processing effect is used.



-- Exact last-location persistence. Interior and room identifiers are saved with
-- the raw player coordinates, and persisted locations are never ground-snapped.
Node7CharselectConfig.LastLocation = {
    Enabled = true,
    PollIntervalMs = 1000,
    AutoSaveIntervalMs = 15000,
    ForceSaveIntervalMs = 60000,
    MinDistance = 0.75,
    MinHeading = 8.0,
    SaveOnInteriorChange = true
}

-- Used only for the post-spawn Red Dead-style location title card. Characters
-- still spawn exclusively at their persisted last location.
Node7CharselectConfig.Locations = {
    { label = 'VALENTINE', region = 'New Hanover', x = -283.8, y = 806.4, radius = 720.0 },
    { label = 'RHODES', region = 'Lemoyne', x = 1231.0, y = -1299.0, radius = 720.0 },
    { label = 'SAINT DENIS', region = 'Lemoyne', x = 2512.0, y = -1305.0, radius = 1050.0 },
    { label = 'BLACKWATER', region = 'West Elizabeth', x = -875.0, y = -1328.0, radius = 820.0 },
    { label = 'STRAWBERRY', region = 'West Elizabeth', x = -1788.0, y = -374.0, radius = 650.0 },
    { label = 'ARMADILLO', region = 'New Austin', x = -3685.0, y = -2623.0, radius = 780.0 },
    { label = 'TUMBLEWEED', region = 'New Austin', x = -5515.0, y = -2930.0, radius = 720.0 },
    { label = 'ANNESBURG', region = 'New Hanover', x = 2934.0, y = 1284.0, radius = 760.0 },
    { label = 'VAN HORN', region = 'New Hanover', x = 2983.0, y = 570.0, radius = 640.0 },
    { label = 'EMERALD RANCH', region = 'New Hanover', x = 1420.0, y = 324.0, radius = 650.0 },
    { label = 'COLTER', region = 'Ambarino', x = -1346.0, y = 2425.0, radius = 700.0 }
}
