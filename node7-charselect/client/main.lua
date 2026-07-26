local Config = Node7CharselectConfig or {}

local uiOpen = false
local selecting = false
local camA = nil
local camB = nil
local pending = {}
local requestId = 0
local spawning = false
local spawnGeneration = 0
local appearanceReady = false
local logoutInProgress = false
local characterActive = false
local lastSavedPosition = nil
local lastSavedAt = 0

local function debugPrint(message)
    if Config.Debug then
        print(('^3[node7-charselect]^7 %s'):format(tostring(message)))
    end
end


local function sendTransition(stage, progress, playerData, options)
    options = type(options) == 'table' and options or {}
    local info = type(playerData) == 'table' and type(playerData.charinfo) == 'table' and playerData.charinfo or {}
    local fullName = (('%s %s'):format(tostring(info.firstname or ''), tostring(info.lastname or ''))):match('^%s*(.-)%s*$')
    if fullName == '' then fullName = options.name or 'Preparing your story' end

    SendNUIMessage({
        action = 'transition',
        kicker = options.kicker or 'NODE7 FRONTIER',
        title = options.title or 'LOADING CHARACTER',
        name = fullName,
        stage = stage or 'Preparing character data',
        hint = options.hint or 'Please remain patient while the frontier is prepared.',
        progress = tonumber(progress) or 0
    })
end

local function closeTransition()
    SendNUIMessage({ action = 'transitionClose' })
end

local function nextRequest()
    requestId = requestId + 1
    if requestId > 999999 then requestId = 1 end
    return requestId
end

local function vec(data, fallback)
    data = type(data) == 'table' and data or fallback or {}
    fallback = type(fallback) == 'table' and fallback or {}
    local interior = tonumber(data.interior or data.interiorId or fallback.interior or fallback.interiorId) or 0
    local room = tonumber(data.room or data.roomKey or fallback.room or fallback.roomKey) or 0
    local isInterior = data.isInterior == true or fallback.isInterior == true or interior ~= 0 or room ~= 0
    return {
        x = tonumber(data.x or data[1]) or tonumber(fallback.x) or -325.06,
        y = tonumber(data.y or data[2]) or tonumber(fallback.y) or 773.62,
        z = tonumber(data.z or data[3]) or tonumber(fallback.z) or 117.43,
        w = tonumber(data.w or data.h or data.heading or data[4]) or tonumber(fallback.w or fallback.h or fallback.heading) or 286.0,
        interior = interior,
        room = room,
        isInterior = isInterior
    }
end

local function getScenePlayerPos()
    return vec(Config.Scene and Config.Scene.player, { x = -562.91, y = -3776.25, z = 237.63, w = 90.0 })
end

local function safeNativeNumber(native, ...)
    if type(native) ~= 'function' then return 0 end
    local ok, value = pcall(native, ...)
    return ok and tonumber(value) or 0
end

local function capturePosition(ped)
    ped = ped or PlayerPedId()
    if not ped or ped == 0 or not DoesEntityExist(ped) then return nil end
    local coords = GetEntityCoords(ped)
    local interior = safeNativeNumber(GetInteriorFromEntity, ped)
    if interior == 0 and type(GetInteriorFromCollision) == 'function' then
        interior = safeNativeNumber(GetInteriorFromCollision, coords.x, coords.y, coords.z)
    end
    local room = safeNativeNumber(GetRoomKeyFromEntity, ped)
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = GetEntityHeading(ped),
        interior = interior,
        room = room,
        isInterior = interior ~= 0 or room ~= 0
    }
end

local function positionDistance(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' then return math.huge end
    local dx = (tonumber(a.x) or 0.0) - (tonumber(b.x) or 0.0)
    local dy = (tonumber(a.y) or 0.0) - (tonumber(b.y) or 0.0)
    local dz = (tonumber(a.z) or 0.0) - (tonumber(b.z) or 0.0)
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

local function headingDifference(a, b)
    local difference = math.abs((tonumber(a) or 0.0) - (tonumber(b) or 0.0)) % 360.0
    return difference > 180.0 and (360.0 - difference) or difference
end

local function setEntityCoordsExact(ped, pos)
    local ok = false
    if type(SetEntityCoordsNoOffset) == 'function' then
        ok = pcall(SetEntityCoordsNoOffset, ped, pos.x, pos.y, pos.z, false, false, false)
    end
    if not ok then
        SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    end
    SetEntityHeading(ped, pos.w)
end

local function prepareInterior(pos)
    local interior = tonumber(pos and pos.interior) or 0
    if interior == 0 then return end
    if type(PinInteriorInMemory) == 'function' then pcall(PinInteriorInMemory, interior) end
    if type(RefreshInterior) == 'function' then pcall(RefreshInterior, interior) end
end

local function waitForWorldReady(ped, pos, timeoutMs)
    local deadline = GetGameTimer() + math.max(1000, tonumber(timeoutMs) or 7000)
    local stableSince = nil
    local stableRequired = tonumber((Config.SpawnFlow or {}).WorldStableMs) or 250
    local interior = tonumber(pos.interior) or 0

    prepareInterior(pos)
    if type(SetFocusPosAndVel) == 'function' then
        pcall(SetFocusPosAndVel, pos.x, pos.y, pos.z, 0.0, 0.0, 0.0)
    end

    while GetGameTimer() < deadline do
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        local collisionReady = HasCollisionLoadedAroundEntity(ped)
        local interiorReady = true
        if interior ~= 0 and type(IsInteriorReady) == 'function' then
            local ok, ready = pcall(IsInteriorReady, interior)
            interiorReady = not ok or ready == true
        end

        if collisionReady and interiorReady then
            stableSince = stableSince or GetGameTimer()
            if GetGameTimer() - stableSince >= stableRequired then break end
        else
            stableSince = nil
        end
        Wait(0)
    end

    setEntityCoordsExact(ped, pos)
    Wait(100)
    if type(ClearFocus) == 'function' then pcall(ClearFocus) end
    return HasCollisionLoadedAroundEntity(ped)
end


local function normalizeGender(gender)
    local raw = tostring(gender or ''):lower():match('^%s*(.-)%s*$') or ''
    if raw == 'female' or raw == 'woman' or raw == 'f' or raw == '0' then return 'female' end
    return 'male'
end

local function genderModel(gender)
    return normalizeGender(gender) == 'female' and 'mp_female' or 'mp_male'
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(tostring(model))
    local okCd, exists = pcall(IsModelInCdimage, hash)
    if okCd and exists == false then return false, 'model_not_found' end
    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        RequestModel(hash)
        Wait(0)
    end
    if not HasModelLoaded(hash) then return false, 'model_load_timeout' end
    return true, hash
end

local function updatePed(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    pcall(function() Citizen.InvokeNative(0x704C908E9C405136, ped) end)
    pcall(function() Citizen.InvokeNative(0xAAB86462966168CE, ped, true) end)
    pcall(function() Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, 0, true, true, true, false) end)
    pcall(function() Citizen.InvokeNative(0x283978A15512B2FE, ped, true) end)
end

local function forceVisible(ped)
    ped = ped or PlayerPedId()
    if not ped or ped == 0 then return end
    SetEntityVisible(ped, true, false)
    SetEntityAlpha(ped, 255, false)
    ResetEntityAlpha(ped)
    SetEntityCollision(ped, true, true)
    updatePed(ped)
end

local function applyShopItem(ped, hash)
    if not ped or ped == 0 or not DoesEntityExist(ped) or not hash then return end
    local ok = pcall(function() ApplyShopItemToPed(ped, hash, true, true, true) end)
    if not ok then
        pcall(function() Citizen.InvokeNative(0xD3A7B003ED343FD9, ped, hash, true, true, true) end)
    end
end

local function applyBaseBody(ped, gender)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end
    local male = normalizeGender(gender) ~= 'female'
    local parts = male and {
        0x158CB7F2, -- head
        361562633, -- hair
        62321923,  -- hands
        3550965899, -- legs
        612262189, -- eyes
        319152566,
        0x2CD2CB71, -- shirt
        0x151EAB71, -- boots
        0x1A6D27DD  -- pants
    } or {
        0x1E6FDDFB, -- head
        272798698, -- hair
        869083847, -- eyes
        736263364, -- hands
        0x193FCEC4, -- shirt
        0x285F3566, -- pants
        0x134D7E03  -- boots
    }
    for _, hash in ipairs(parts) do
        applyShopItem(ped, hash)
        Wait(0)
    end
    forceVisible(ped)
end

local function setPlayerModel(gender)
    local model = genderModel(gender)
    local ok, hashOrError = loadModel(model)
    if not ok then return false, hashOrError end

    local applied = pcall(function() SetPlayerModel(PlayerId(), hashOrError, false) end)
    if not applied then
        applied = pcall(function() Citizen.InvokeNative(0xED40380076A31506, PlayerId(), hashOrError, false) end)
    end
    if not applied then
        applied = pcall(function() SetPlayerModel(PlayerId(), hashOrError) end)
    end
    if not applied then return false, 'set_player_model_failed' end

    Wait(350)
    pcall(SetModelAsNoLongerNeeded, hashOrError)
    local ped = PlayerPedId()
    applyBaseBody(ped, gender)
    forceVisible(ped)
    return true
end

local function destroyCams()
    RenderScriptCams(false, true, 250, true, true)
    if camA and DoesCamExist(camA) then DestroyCam(camA, true) end
    if camB and DoesCamExist(camB) then DestroyCam(camB, true) end
    camA = nil
    camB = nil
    ClearTimecycleModifier()
end

local function createCams()
    destroyCams()
    local scene = Config.Scene or {}
    local intro = scene.introCam or {}
    local fixed = scene.fixedCam or {}

    camA = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camA, intro.x or -555.925, intro.y or -3778.709, intro.z or 238.597)
    SetCamRot(camA, intro.rx or -20.0, intro.ry or 0.0, intro.rz or 83.0, 2)
    SetCamFov(camA, intro.fov or 30.0)
    SetCamActive(camA, true)

    camB = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(camB, fixed.x or -561.206, fixed.y or -3776.224, fixed.z or 239.597)
    SetCamRot(camB, fixed.rx or -20.0, fixed.ry or 0.0, fixed.rz or 270.0, 2)
    SetCamFov(camB, fixed.fov or 30.0)
    SetCamActive(camB, true)

    RenderScriptCams(true, false, 1, true, true)
    SetCamActiveWithInterp(camB, camA, 900, true, true)
    SetTimecycleModifier('default')
end

local function closeUi()
    uiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function prepareScene()
    selecting = true
    local ped = PlayerPedId()
    local pos = getScenePlayerPos()

    DoScreenFadeOut(150)
    Wait(250)
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(ped, pos.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)
    DisplayRadar(false)
    createCams()
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(400)
end

local function getLastLocation(playerData)
    local defaultSpawn = vec(Config.DefaultSpawn, { x = -325.06, y = 773.62, z = 117.43, w = 286.0 })

    if type(playerData) == 'table' and type(playerData.position) == 'table' then
        local saved = vec(playerData.position, defaultSpawn)
        if saved.x and saved.y and saved.z then return saved, true end
    end

    return defaultSpawn, false
end

local function resolveGround(pos)
    if pos.isInterior or tonumber(pos.interior or 0) ~= 0 or tonumber(pos.room or 0) ~= 0 then
        return pos
    end
    local ok, found, groundZ = pcall(function()
        return GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 80.0, false)
    end)
    if ok and found and type(groundZ) == 'number' and groundZ > -100.0 then
        pos.z = groundZ + 0.05
    end
    return pos
end

local function markAppearanceReady()
    if spawning then appearanceReady = true end
end

RegisterNetEvent('node7-charselect:client:appearanceReady', markAppearanceReady)
RegisterNetEvent('node7-appearance:client:loaded', markAppearanceReady)
RegisterNetEvent('node7-appearance:client:appearanceLoaded', markAppearanceReady)
RegisterNetEvent('node7-skins:client:skinLoaded', markAppearanceReady)

local function requestSavedAppearance()
    if Config.LoadSavedSkinOnSpawn == false then return true end

    local appearanceResource = Config.AppearanceResource or 'node7-appearance'
    local skinsResource = Config.SkinsResource or 'node7-skins'
    local requested = false
    appearanceReady = false

    if GetResourceState(appearanceResource) == 'started' then
        TriggerServerEvent('node7-appearance:server:loadSaved')
        requested = true
    elseif GetResourceState(skinsResource) == 'started' then
        TriggerServerEvent('node7-skins:server:loadSkin', false)
        requested = true
    end

    if not requested then return true end

    local flow = Config.SpawnFlow or {}
    local minimumEnd = GetGameTimer() + (tonumber(flow.AppearanceMinimumWaitMs) or 900)
    local timeout = GetGameTimer() + (tonumber(flow.AppearanceTimeoutMs) or 3500)

    while GetGameTimer() < minimumEnd do Wait(0) end
    while not appearanceReady and GetGameTimer() < timeout do Wait(25) end

    if not appearanceReady then
        debugPrint('Appearance resource did not emit a ready event before timeout; continuing safely.')
    end
    return true
end

local function openAppearanceCreator()
    if Config.OpenAppearanceForNewCharacters == false then return end
    CreateThread(function()
        Wait(900)
        SendNUIMessage({ action = 'hideLocation' })
        local appearanceResource = Config.AppearanceResource or 'node7-appearance'
        local skinsResource = Config.SkinsResource or 'node7-skins'
        if GetResourceState(appearanceResource) == 'started' then
            TriggerEvent('node7-appearance:client:openCreator')
        elseif GetResourceState(skinsResource) == 'started' then
            TriggerEvent('node7-skins:client:openCreator')
        end
    end)
end

local function nearestLocation(pos)
    local nearest, nearestDistance = nil, math.huge
    for _, location in ipairs(Config.Locations or {}) do
        local dx = pos.x - (tonumber(location.x) or 0.0)
        local dy = pos.y - (tonumber(location.y) or 0.0)
        local distance = math.sqrt((dx * dx) + (dy * dy))
        local radius = tonumber(location.radius) or 650.0
        if distance <= radius and distance < nearestDistance then
            nearest = location
            nearestDistance = distance
        end
    end
    return nearest or { label = 'THE FRONTIER', region = 'Your last known location' }
end

local function clockLabel()
    local hour = tonumber(GetClockHours()) or 0
    local minute = tonumber(GetClockMinutes()) or 0
    local suffix = hour >= 12 and 'PM' or 'AM'
    local displayHour = hour % 12
    if displayHour == 0 then displayHour = 12 end
    return ('%d:%02d %s'):format(displayHour, minute, suffix)
end

local function showLocationCard(pos, created)
    local flow = Config.SpawnFlow or {}
    local location = nearestLocation(pos)
    SendNUIMessage({
        action = 'location',
        kicker = created and 'YOUR STORY BEGINS' or 'RETURNING TO',
        title = tostring(location.label or 'THE FRONTIER'),
        subtitle = tostring(location.region or 'Your last known location'),
        time = clockLabel(),
        duration = tonumber(flow.LocationCardMs) or 4200
    })
end

local function recoverFromSpawn(reason, generation)
    if generation and generation ~= spawnGeneration then return end
    debugPrint(('Spawn recovery activated: %s'):format(tostring(reason or 'unknown')))
    spawnGeneration = spawnGeneration + 1
    spawning = false
    selecting = false
    appearanceReady = false
    characterActive = true
    destroyCams()
    closeUi()

    local ped = PlayerPedId()
    if ped and ped ~= 0 then
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        SetEntityCollision(ped, true, true)
        forceVisible(ped)
    end
    DisplayRadar(true)
    if IsScreenFadedOut() or IsScreenFadingOut() then DoScreenFadeIn(500) end
    closeTransition()
end

local function beginSpawnWatchdog(generation)
    local flow = Config.SpawnFlow or {}
    CreateThread(function()
        Wait(tonumber(flow.MaxSpawnMs) or 30000)
        if spawning and generation == spawnGeneration then
            recoverFromSpawn('spawn_watchdog_timeout', generation)
        end
    end)
end

local function finishSpawn(playerData, created)
    if spawning then return end
    spawning = true
    spawnGeneration = spawnGeneration + 1
    local generation = spawnGeneration
    beginSpawnWatchdog(generation)

    playerData = type(playerData) == 'table' and playerData or {}
    local gender = playerData.charinfo and playerData.charinfo.gender or 'male'
    local pos, persisted = getLastLocation(playerData)
    if not persisted then pos = resolveGround(pos) end
    local flow = Config.SpawnFlow or {}

    sendTransition('Securing your character record', 12, playerData)
    DoScreenFadeOut(Config.FadeOutMs or 300)
    local fadeTimeout = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < fadeTimeout do Wait(0) end

    closeUi()
    selecting = false
    destroyCams()

    sendTransition('Loading your character model', 26, playerData)
    local modelReady, modelError = setPlayerModel(gender)
    if not modelReady then
        recoverFromSpawn(modelError or 'model_load_failed', generation)
        return
    end

    local ped = PlayerPedId()
    sendTransition(persisted and 'Returning to your exact last location' or 'Preparing your first location', 42, playerData)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetEntityCollision(ped, false, false)
    setEntityCoordsExact(ped, pos)
    forceVisible(ped)
    DisplayRadar(false)

    sendTransition(pos.isInterior and 'Preparing the building interior' or 'Loading the world around you', 58, playerData)
    waitForWorldReady(ped, pos, tonumber(flow.CollisionTimeoutMs) or 9000)
    SetEntityCollision(ped, true, true)
    setEntityCoordsExact(ped, pos)

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set('node7CharselectActive', false, false)
        LocalPlayer.state:set('isLoggedIn', true, false)
    end
    characterActive = true

    TriggerEvent('Node7Core:Client:OnPlayerLoaded')
    TriggerEvent('node7-core:client:playerLoaded', playerData)

    if not created then
        sendTransition('Restoring your saved appearance', 76, playerData)
        requestSavedAppearance()
        forceVisible(ped)
        setEntityCoordsExact(ped, pos)
    end

    sendTransition(created and 'Preparing your first arrival' or 'Finalizing your last location', 92, playerData, {
        title = created and 'YOUR STORY BEGINS' or 'ENTERING THE FRONTIER',
        hint = 'The world is ready. Returning control to you now.'
    })

    -- Final handoff uses only RedM's native screen fade. No wake animation,
    -- scripted camera, entity dissolve, or post-processing effect is played.
    Wait(tonumber(flow.NativeBlackHoldMs) or 150)
    if type(ClearPedTasksImmediately) == 'function' then
        pcall(ClearPedTasksImmediately, ped)
    else
        pcall(ClearPedTasks, ped)
    end
    closeTransition()
    DoScreenFadeIn(Config.FadeInMs or 850)
    local fadeInDeadline = GetGameTimer() + math.max(1500, (tonumber(Config.FadeInMs) or 850) + 1000)
    while not IsScreenFadedIn() and GetGameTimer() < fadeInDeadline do Wait(0) end

    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityCollision(ped, true, true)
    forceVisible(ped)
    DisplayRadar(true)

    local finalPosition = capturePosition(ped) or pos
    TriggerServerEvent('node7-charselect:server:savePosition', finalPosition)
    lastSavedPosition = finalPosition
    lastSavedAt = GetGameTimer()
    TriggerEvent('node7-charselect:client:spawned', finalPosition, playerData)
    showLocationCard(finalPosition, created == true)

    spawning = false
    appearanceReady = false

    if created then openAppearanceCreator() end
end

exports('MarkAppearanceReady', markAppearanceReady)
exports('IsSpawning', function() return spawning end)

local function serverRequest(kind, ...)
    local id = nextRequest()
    local p = promise.new()
    pending[id] = p

    if kind == 'characters' then
        TriggerServerEvent('node7-charselect:server:requestCharacters', id)
    elseif kind == 'create' then
        TriggerServerEvent('node7-charselect:server:createCharacter', id, ...)
    elseif kind == 'select' then
        TriggerServerEvent('node7-charselect:server:selectCharacter', id, ...)
    elseif kind == 'delete' then
        TriggerServerEvent('node7-charselect:server:deleteCharacter', id, ...)
    end

    SetTimeout(10000, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ ok = false, error = 'server_timeout' })
        end
    end)

    return Citizen.Await(p)
end

RegisterNetEvent('node7-charselect:client:characters', function(id, characters, slots, error)
    local result = { ok = error == nil, characters = characters or {}, slots = slots or Config.DefaultNumberOfCharacters or 4, error = error }
    if id and id ~= 0 and pending[id] then
        local p = pending[id]
        pending[id] = nil
        p:resolve(result)
        return
    end
    SendNUIMessage({ action = 'characters', characters = result.characters, slots = result.slots, error = result.error })
end)

RegisterNetEvent('node7-charselect:client:createResult', function(id, ok, data)
    if not pending[id] then return end
    local p = pending[id]
    pending[id] = nil
    p:resolve({ ok = ok == true, character = ok and data or nil, error = ok and nil or tostring(data) })
end)

RegisterNetEvent('node7-charselect:client:selectResult', function(id, ok, playerData, created)
    if not pending[id] then return end
    local p = pending[id]
    pending[id] = nil
    if ok == true then
        p:resolve({ ok = true, player = playerData, created = created == true })
    else
        p:resolve({ ok = false, error = tostring(playerData) })
    end
end)

RegisterNetEvent('node7-charselect:client:deleteResult', function(id, ok, err)
    if not pending[id] then return end
    local p = pending[id]
    pending[id] = nil
    p:resolve({ ok = ok == true, error = ok and nil or tostring(err) })
end)

local function openCharselect()
    if uiOpen then return end
    logoutInProgress = false
    spawning = false
    appearanceReady = false
    characterActive = false
    lastSavedPosition = nil
    closeTransition()
    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set('node7Loaded', true, false)
        LocalPlayer.state:set('node7CharselectActive', true, false)
        LocalPlayer.state:set('isLoggedIn', false, false)
    end
    uiOpen = true
    prepareScene()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        slots = Config.DefaultNumberOfCharacters or 4
    })
    TriggerServerEvent('node7-charselect:server:beginSelection')
end

RegisterNetEvent('node7-charselect:client:chooseChar', openCharselect)
RegisterNetEvent('node7-charselect:client:open', openCharselect)
RegisterNetEvent('node7-multicharacter:client:chooseChar', openCharselect)
RegisterNetEvent('node7-multicharacter:client:open', openCharselect)

RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    cb(serverRequest('characters'))
end)

RegisterNUICallback('createCharacter', function(data, cb)
    local result = serverRequest('create', data or {})
    cb(result)
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    data = type(data) == 'table' and data or {}
    local result = serverRequest('select', data.citizenid)
    cb(result)
    if result.ok then
        CreateThread(function()
            Wait(0)
            finishSpawn(result.player, result.created)
        end)
    end
end)

RegisterNUICallback('deleteCharacter', function(data, cb)
    data = type(data) == 'table' and data or {}
    local result = serverRequest('delete', data.citizenid)
    if result.ok then
        local chars = serverRequest('characters')
        SendNUIMessage({ action = 'characters', characters = chars.characters or {}, slots = chars.slots or Config.DefaultNumberOfCharacters or 4 })
    end
    cb(result)
end)

RegisterNUICallback('disconnect', function(_, cb)
    TriggerServerEvent('node7-charselect:server:disconnect')
    cb({ ok = true })
end)

local function requestLogout()
    if logoutInProgress or selecting or spawning then return end
    logoutInProgress = true

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    Wait(75)
    local position = capturePosition(ped)
    if not position then
        logoutInProgress = false
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        return
    end
    characterActive = false

    DisplayRadar(false)
    sendTransition(position.isInterior and 'Saving your position inside this building' or 'Saving your exact last location', 38, nil, {
        kicker = 'NODE7 CHARACTER SERVICE',
        title = 'RETURNING TO ROSTER',
        name = 'Your progress is being secured',
        hint = 'Do not disconnect while your character is being saved.'
    })

    DoScreenFadeOut(Config.FadeOutMs or 300)
    TriggerServerEvent('node7-charselect:server:logout', position)

    local flow = Config.SpawnFlow or {}
    CreateThread(function()
        Wait(tonumber(flow.LogoutTimeoutMs) or 12000)
        if logoutInProgress and not uiOpen then
            logoutInProgress = false
            characterActive = true
            FreezeEntityPosition(ped, false)
            SetEntityInvincible(ped, false)
            DisplayRadar(true)
            DoScreenFadeIn(500)
            closeTransition()
        end
    end)
end

RegisterNetEvent('node7-charselect:client:prepareLogout', requestLogout)

RegisterCommand('charselect', requestLogout, false)
RegisterCommand('characters', requestLogout, false)
RegisterCommand('logout', requestLogout, false)

CreateThread(function()
    while true do
        local settings = Config.LastLocation or {}
        Wait(math.max(500, tonumber(settings.PollIntervalMs) or 1000))

        if settings.Enabled ~= false and characterActive and not selecting and not spawning and not logoutInProgress then
            local current = capturePosition(PlayerPedId())
            if current then
                local now = GetGameTimer()
                local moved = positionDistance(current, lastSavedPosition) >= (tonumber(settings.MinDistance) or 0.75)
                local turned = lastSavedPosition and headingDifference(current.w, lastSavedPosition.w) >= (tonumber(settings.MinHeading) or 8.0)
                local interiorChanged = lastSavedPosition and (current.isInterior ~= lastSavedPosition.isInterior or current.interior ~= lastSavedPosition.interior or current.room ~= lastSavedPosition.room)
                local intervalDue = now - lastSavedAt >= (tonumber(settings.AutoSaveIntervalMs) or 15000)
                local forceDue = now - lastSavedAt >= (tonumber(settings.ForceSaveIntervalMs) or 60000)

                if (settings.SaveOnInteriorChange ~= false and interiorChanged) or forceDue or (intervalDue and (moved or turned)) then
                    TriggerServerEvent('node7-charselect:server:savePosition', current)
                    lastSavedPosition = current
                    lastSavedAt = now
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeUi()
    closeTransition()
    selecting = false
    spawning = false
    logoutInProgress = false
    characterActive = false
    destroyCams()
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityCollision(ped, true, true)
    SetEntityVisible(ped, true, false)
    forceVisible(ped)
    DisplayRadar(true)
end)

CreateThread(function()
    while not NetworkIsSessionStarted() or not NetworkIsPlayerActive(PlayerId()) do
        Wait(250)
    end
    Wait(500)
    openCharselect()
end)
