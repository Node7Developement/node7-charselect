local Config = Node7CharselectConfig or {}

local uiOpen = false
local selecting = false
local camA = nil
local camB = nil
local pending = {}
local requestId = 0
local spawning = false

local function debugPrint(message)
    if Config.Debug then
        print(('^3[node7-charselect]^7 %s'):format(tostring(message)))
    end
end

local function nextRequest()
    requestId = requestId + 1
    if requestId > 999999 then requestId = 1 end
    return requestId
end

local function vec(data, fallback)
    data = type(data) == 'table' and data or fallback or {}
    fallback = type(fallback) == 'table' and fallback or {}
    return {
        x = tonumber(data.x or data[1]) or tonumber(fallback.x) or -325.06,
        y = tonumber(data.y or data[2]) or tonumber(fallback.y) or 773.62,
        z = tonumber(data.z or data[3]) or tonumber(fallback.z) or 117.43,
        w = tonumber(data.w or data.h or data.heading or data[4]) or tonumber(fallback.w or fallback.h or fallback.heading) or 286.0
    }
end

local function getScenePlayerPos()
    return vec(Config.Scene and Config.Scene.player, { x = -562.91, y = -3776.25, z = 237.63, w = 90.0 })
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
        return vec(playerData.position, defaultSpawn)
    end

    return defaultSpawn
end

local function resolveGround(pos)
    local ok, found, groundZ = pcall(function()
        return GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 80.0, false)
    end)
    if ok and found and type(groundZ) == 'number' and groundZ > -100.0 then
        pos.z = groundZ + 0.05
    end
    return pos
end

local function triggerAppearanceLoad(created)
    CreateThread(function()
        Wait(created and 700 or 450)
        if created and Config.OpenAppearanceForNewCharacters ~= false then
            if GetResourceState(Config.AppearanceResource or 'node7-appearance') == 'started' then
                TriggerEvent('node7-appearance:client:openCreator')
                return
            end
            if GetResourceState(Config.SkinsResource or 'node7-skins') == 'started' then
                TriggerEvent('node7-skins:client:openCreator')
                return
            end
        end

        if Config.LoadSavedSkinOnSpawn ~= false then
            if GetResourceState(Config.AppearanceResource or 'node7-appearance') == 'started' then
                TriggerServerEvent('node7-appearance:server:loadSaved')
                return
            end
            if GetResourceState(Config.SkinsResource or 'node7-skins') == 'started' then
                TriggerServerEvent('node7-skins:server:loadSkin', false)
            end
        end
    end)
end

local function finishSpawn(playerData, created)
    if spawning then return end
    spawning = true

    playerData = type(playerData) == 'table' and playerData or {}
    local gender = playerData.charinfo and playerData.charinfo.gender or 'male'
    local pos = resolveGround(getLastLocation(playerData))

    DoScreenFadeOut(Config.FadeOutMs or 250)
    local fadeTimeout = GetGameTimer() + 3000
    while not IsScreenFadedOut() and GetGameTimer() < fadeTimeout do Wait(0) end

    closeUi()
    selecting = false
    destroyCams()

    setPlayerModel(gender)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(ped, pos.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, false)
    SetEntityCollision(ped, true, true)
    forceVisible(ped)

    local timeout = GetGameTimer() + 6000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < timeout do
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        Wait(0)
    end

    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
    forceVisible(ped)
    DisplayRadar(true)
    DoScreenFadeIn(Config.FadeInMs or 650)

    TriggerServerEvent('node7-charselect:server:savePosition', { x = pos.x, y = pos.y, z = pos.z, w = pos.w })
    TriggerEvent('node7-charselect:client:spawned', pos, playerData)
    TriggerEvent('Node7Core:Client:OnPlayerLoaded')
    TriggerEvent('node7-core:client:playerLoaded', playerData)
    triggerAppearanceLoad(created == true)

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state:set('node7CharselectActive', false, false)
        LocalPlayer.state:set('isLoggedIn', true, false)
    end

    spawning = false
end

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

RegisterCommand('charselect', function()
    TriggerServerEvent('node7-charselect:server:logout')
end, false)

RegisterCommand('characters', function()
    TriggerServerEvent('node7-charselect:server:logout')
end, false)

RegisterCommand('logout', function()
    TriggerServerEvent('node7-charselect:server:logout')
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    closeUi()
    selecting = false
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
