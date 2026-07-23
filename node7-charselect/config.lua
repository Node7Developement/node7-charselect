Node7CharSelectConfig = {}

Node7CharSelectConfig.Debug = false
Node7CharSelectConfig.MaxCharacters = 4
Node7CharSelectConfig.AllowDelete = true
Node7CharSelectConfig.OpenDelay = 700
Node7CharSelectConfig.ReopenCommand = 'charselect'
Node7CharSelectConfig.LegacyReopenCommands = { 'character', 'characters' }
Node7CharSelectConfig.LogoutCommand = 'logout'
Node7CharSelectConfig.RequestTimeout = 8000
Node7CharSelectConfig.ModelLoadTimeout = 6000

-- Visible selector preview models. node7-skins replaces these with saved skin during final load.
Node7CharSelectConfig.GenderModels = {
    male = 'a_m_m_valtownfolk_01',
    female = 'a_f_m_valtownfolk_01'
}

Node7CharSelectConfig.ApplyRandomOutfitVariation = false

Node7CharSelectConfig.Skins = {
    enabled = true,
    resource = 'node7-skins',
    clientEvent = 'node7-skins:client:loadSkin',
    applyBeforeSpawn = true,
    openCreatorOnFirstCreate = false,
    FallbackToGenderModelWhenMissing = true,
    waitMs = 2500
}

-- Clothing resources are optional and detected at runtime so charselect does not refuse to start.
-- First started resource in this list gets the saved-clothing load event after spawn.
Node7CharSelectConfig.Clothing = {
    enabled = false,
    delayAfterSpawn = 0,
    resources = {}
}

Node7CharSelectConfig.PreviewPed = {
    enabled = false,
    visible = true,
    defaultGender = 'male'
}

-- Play spawns directly at the saved player position.
-- This fallback is only for brand-new characters or broken/missing stored positions.
Node7CharSelectConfig.FirstSpawnPosition = {
    x = -325.06,
    y = 773.62,
    z = 117.43,
    w = 286.0
}



-- RedEMRP charselect-inspired scene position, kept safe and stable for one visible selector ped.
Node7CharSelectConfig.SelectorPosition = {
    x = 1343.67,
    y = -1304.22,
    z = 76.44,
    w = 160.38
}

Node7CharSelectConfig.Camera = {
    enabled = true,
    x = 1342.34,
    y = -1308.10,
    z = 78.02,
    rotationX = -8.0,
    rotationY = 0.0,
    rotationZ = -19.08,
    fov = 48.0
}

Node7CharSelectConfig.BadPositionFallback = true
Node7CharSelectConfig.BadPositionFallbackMessage = 'Saved location was missing or unsafe, using safe Valentine spawn.'
Node7CharSelectConfig.GroundProbe = true

Node7CharSelectConfig.BadPositions = {
    { x = 0.0, y = 0.0, z = 0.0, radius = 75.0 },
    { x = -540.48, y = -2125.75, z = 6.01, radius = 35.0 }
}

Node7CharSelectConfig.RequiredFields = {
    firstname = { min = 2, max = 50 },
    lastname = { min = 2, max = 50 },
    birthdate = { min = 6, max = 20 },
    gender = { min = 1, max = 20 },
    nationality = { min = 2, max = 50 },
    backstory = { min = 0, max = 500 }
}

Node7CharSelectConfig.DefaultLabels = {
    title = 'NODE7 CHARSELECT',
    subtitle = '',
    create = 'Create Character',
    setup = 'Finish Setup',
    play = 'Play',
    delete = 'Delete'
}

-- RedEMRP charselect scene format preserved for NODE7 charselect preview/camera positions.
Node7CharSelectConfig.DefaultCharScene = 2
Node7CharSelectConfig.CharScene = 2
Node7CharSelectConfig.CharScenes = {
    [1] = {
        MainPedCoord = vector3(322.86, 1477.40, 182.94),
        [1] = {
            PedCoord = vector4(317.19186, 1493.2331, 180.38209, 293.07723),
            CamCoord = vector4(320.56, 1495.70, 182.32, 125.82),
            Scenario = GetHashKey("MP_LOBBY_WORLD_HUMAN_STERNGUY_IDLES"),
            Light = true,
        },
        [2] = {
            PedCoord = vector4(355.38494, 1501.522, 179.05319, 152.73977),
            CamCoord = vector4(354.29, 1498.29, 181.59, -19.22),
            Scenario = GetHashKey("WORLD_HUMAN_FARMER_RAKE"),
            Light = true,
        },
        [3] = {
            PedCoord = vector4(363.13137, 1519.0736, 183.86787, 341.47839),
            CamCoord = vector4(363.66, 1521.63, 185.43, 168.29),
            Scenario = GetHashKey("WORLD_HUMAN_SMOKE"),
            Light = true,
        },
        [4] = {
            PedCoord = vector4(335.97897, 1506.16, 180.87527, 201.00424),
            CamCoord = vector4(337.78, 1503.88, 183.00, 28.46),
            Scenario = GetHashKey("WORLD_HUMAN_COFFEE_DRINK"),
            Light = true,
        },
    },
    [2] = {
        MainPedCoord = vector3(1348.7363, -1283.445, 76.945556),
        [1] = {
            PedCoord = vector4(1343.6759, -1304.229, 76.443367, 160.38618),
            CamCoord = vector4(1342.34, -1308.10, 78.02, -19.08),
            Scenario = GetHashKey("WORLD_HUMAN_LEAN_POST_LEFT"),
            Light = true,
        },
        [2] = {
            PedCoord = vector4(1328.1425, -1292.192, 76.024002, 165.39581),
            CamCoord = vector4(1327.58, -1295.30, 77.88, -10.30),
            Scenario = GetHashKey("WORLD_HUMAN_STRAW_BROOM_WORKING"),
            Light = true,
        },
        [3] = {
            PedCoord = vector4(1299.1282, -1298.091, 76.03231, 318.45025),
            CamCoord = vector4(1301.54, -1295.10, 77.51, 141.06),
            Scenario = GetHashKey("WORLD_HUMAN_SMOKE"),
            Light = true,
        },
        [4] = {
            PedCoord = vector4(1326.4974, -1297.386, 75.997756, 209.03295),
            CamCoord = vector4(1324.36, -1301.79, 77.81, -25.96),
            Scenario = GetHashKey("WORLD_HUMAN_STRAW_BROOM_WORKING"),
            Light = true,
        },
    },
    [3] = {
        MainPedCoord = vector3(2848.8256, -1383.711, 51.4029),
        [1] = {
            PedCoord = vector4(2885.9868, -1377.585, 43.549419, 232.79244),
            CamCoord = vector4(2890.25, -1380.84, 45.38, 52.44),
            ScenarioMale = GetHashKey("WORLD_HUMAN_STAND_FISHING"),
            ScenarioFemale = GetHashKey("WORLD_HUMAN_SMOKE"),
            CamFov = 60.0,
            Light = true,
        },
        [2] = {
            PedCoord = vector4(2825.1398, -1388.31, 44.394477, 231.47293),
            CamCoord = vector4(2828.96, -1391.44, 46.12, 50.28),
            Scenario = GetHashKey("WORLD_HUMAN_COFFEE_DRINK"),
            CamFov = 55.0,
            Light = true,
        },
        [3] = {
            PedCoord = vector4(2825.8806, -1315.758, 45.755668, 231.79319),
            CamCoord = vector4(2827.43, -1319.80, 47.54, 21.44),
            Scenario = GetHashKey("WORLD_HUMAN_STRAW_BROOM_WORKING"),
            Light = true,
        },
        [4] = {
            PedCoord = vector4(2716.9802, -1450.25, 45.253368, 198.39982),
            CamCoord = vector4(2718.97, -1454.41, 47.16, 25.79),
            Scenario = GetHashKey("WORLD_HUMAN_STARE_STOIC"),
            CamFov = 55.0,
            Light = true,
        },
    },
    [4] = {
        MainPedCoord = vector3(-6206.13, -4216.593, -21.11636),
        [1] = {
            PedCoord = vector4(-6229.889, -4236.923, -31.57647, 273.24786),
            CamCoord = vector4(-6226.90, -4238.04, -29.60, 69.45),
            Scenario = GetHashKey("MP_LOBBY_WORLD_HUMAN_STERNGUY_IDLES"),
            Light = true,
        },
        [2] = {
            PedCoord = vector4(-6221.671, -4239.435, -30.72285, 338.93801),
            CamCoord = vector4(-6220.00, -4237.12, -29.53, 145.94),
            Scenario = GetHashKey("WORLD_PLAYER_CAMP_FIRE_SIT"),
            Light = true,
        },
        [3] = {
            PedCoord = vector4(-6255.566, -4227.998, -31.42898, 212.57539),
            CamCoord = vector4(-6252.24, -4230.73, -31.01, 50.65),
            Scenario = GetHashKey("WORLD_HUMAN_SIT_GROUND_COFFEE_DRINK"),
            Light = true,
        },
        [4] = {
            PedCoord = vector4(-6284.626, -4247.803, -31.05393, 224.79016),
            CamCoord = vector4(-6281.59, -4251.04, -29.06, 43.27),
            Scenario = GetHashKey("WORLD_HUMAN_SMOKE"),
            Light = true,
        },
    },
    [5] = {
        MainPedCoord = vector3(-5796.075, -4502.301, -2.121614),
        [1] = {
            PedCoord = vector4(-5786.685, -4482.076, 4.2378883, 66.645843),
            CamCoord = vector4(-5788.88, -4480.18, 5.86, -131.73),
            Scenario = GetHashKey("MP_LOBBY_WORLD_HUMAN_STERNGUY_IDLES"),
            Light = true,
        },
        [2] = {
            PedCoord = vector4(-5749.527, -4507.612, -4.268967, 221.2789),
            CamCoord = vector4(-5746.56, -4509.55, -2.06, 56.65),
            Scenario = GetHashKey("WORLD_HUMAN_COFFEE_DRINK"),
            Light = true,
        },
        [3] = {
            PedCoord = vector4(-5768.778, -4565.91, -9.092725, 196.83442),
            CamCoord = vector4(-5767.77, -4568.69, -6.85, 19.72),
            Scenario = GetHashKey("WORLD_HUMAN_FARMER_RAKE"),
            Light = true,
        },
        [4] = {
            PedCoord = vector4(-5684.958, -4482.919, -9.01317, 104.83269),
            CamCoord = vector4(-5688.86, -4482.85, -6.96, -91.30),
            Scenario = GetHashKey("WORLD_HUMAN_SIT_GROUND_COFFEE_DRINK"),
            Light = true,
        },
    },
}

