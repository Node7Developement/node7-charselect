local Node7Core = exports['node7-core']:GetCoreObject()

local charPed = nil
local selectingChar = true
local isChoosing = false
local menuOpen = false
local previewToken = 0
local selectionSession = 0
local loadRequestPending = false
local loadingCharacter = false
local nativeLoadingActive = false
local cam = nil
local fixedCam = nil

-- Locked to the exact supplied RSG selector placement.
local PLAYER_STAGE = vector4(1542.79, 1187.29, 283.18, -91.68)
local PREVIEW_STAGE = vector4(1544.10, 1187.65, 283.18, -91.68)
local CAMERA_START = vector3(1548.80, 1187.90, 284.29)
local CAMERA_END = vector3(1545.80, 1187.90, 284.29)
local CAMERA_START_ROT = vector3(-20.0, 0.0, 83.0)
local CAMERA_END_ROT = vector3(0.0, 0.0, 100.0)

local function notify(message, notifyType)
    if Node7Core and Node7Core.Functions and Node7Core.Functions.Notify then
        Node7Core.Functions.Notify({
            title = 'NODE7 CHARSELECT',
            description = tostring(message or 'Character action failed.'),
            type = notifyType or 'info',
            duration = 5000,
        })
    end
end

local function decodePosition(position)
    if type(position) == 'string' then
        local ok, decoded = pcall(json.decode, position)
        if ok then position = decoded end
    end

    position = type(position) == 'table' and position or {}
    return {
        x = tonumber(position.x or position[1]) or Config.DefaultSpawn.x,
        y = tonumber(position.y or position[2]) or Config.DefaultSpawn.y,
        z = tonumber(position.z or position[3]) or Config.DefaultSpawn.z,
        w = tonumber(position.w or position.h or position.heading or position[4]) or Config.DefaultSpawn.w,
    }
end

local function setNativeLoadingScreen(enabled, title, subtitle)
    if enabled then
        nativeLoadingActive = true
        pcall(function()
            Citizen.InvokeNative(
                0x1E5B70E53DB661E5,
                1122662550,
                347053089,
                0,
                'NODE7',
                tostring(title or 'YOU ARE WAKING UP'),
                tostring(subtitle or 'Returning to your last location')
            )
        end)
    elseif nativeLoadingActive then
        nativeLoadingActive = false
        pcall(ShutdownLoadingScreen)
        pcall(ShutdownLoadingScreenNui)
    end
end

local function setLoadingOverlay(enabled, isNew, message)
    SendNUIMessage({
        action = 'characterLoading',
        toggle = enabled == true,
        title = 'YOU ARE WAKING UP',
        message = message or (isNew and 'Beginning your story...' or 'Returning to your last location...'),
    })
end

local function stopCharacterLoading(hideUi)
    loadingCharacter = false
    loadRequestPending = false
    setNativeLoadingScreen(false)
    setLoadingOverlay(false)
    pcall(ClearFocus)

    if hideUi then
        SendNUIMessage({ action = 'ui', toggle = false })
    else
        SendNUIMessage({ action = 'characterLoadFailed' })
    end
end

local function deletePreviewPed()
    if charPed and DoesEntityExist(charPed) then
        SetEntityAsMissionEntity(charPed, true, true)
        DeleteEntity(charPed)
    end
    charPed = nil
end

local function hidePlayerAtOriginalStage()
    local ped = PlayerPedId()
    RequestCollisionAtCoord(PLAYER_STAGE.x, PLAYER_STAGE.y, PLAYER_STAGE.z)
    SetEntityCoords(ped, PLAYER_STAGE.x, PLAYER_STAGE.y, PLAYER_STAGE.z, false, false, false, false)
    SetEntityHeading(ped, PLAYER_STAGE.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityCollision(ped, false, false)
    SetEntityVisible(ped, false, false)
    SetEntityAlpha(ped, 0, false)
    pcall(function() NetworkSetEntityInvisibleToNetwork(ped, true) end)
    return ped
end

local function prepareHiddenPlayerForSpawn(position)
    local ped = PlayerPedId()
    pcall(function() SetFocusPosAndVel(position.x, position.y, position.z, 0.0, 0.0, 0.0) end)
    RequestCollisionAtCoord(position.x, position.y, position.z)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetEntityCollision(ped, false, false)
    SetEntityVisible(ped, false, false)
    SetEntityAlpha(ped, 0, false)
    SetEntityCoords(ped, position.x, position.y, position.z, false, false, false, false)
    SetEntityHeading(ped, position.w)
    pcall(function() NetworkSetEntityInvisibleToNetwork(ped, true) end)
end

local function waitForSpawnCollision(ped, position)
    local deadline = GetGameTimer() + 15000
    local loaded = false

    pcall(function() SetFocusPosAndVel(position.x, position.y, position.z, 0.0, 0.0, 0.0) end)
    repeat
        RequestCollisionAtCoord(position.x, position.y, position.z)
        loaded = false
        pcall(function()
            loaded = HasCollisionLoadedAroundEntity(ped)
        end)
        if loaded then break end
        Wait(50)
    until GetGameTimer() >= deadline

    -- Give the final scene a short settling window even if the native timed out.
    Wait(250)
    pcall(ClearFocus)
    return loaded
end

local function preparePreviewPed(ped)
    RequestCollisionAtCoord(PREVIEW_STAGE.x, PREVIEW_STAGE.y, PREVIEW_STAGE.z)
    SetEntityCoords(ped, PREVIEW_STAGE.x, PREVIEW_STAGE.y, PREVIEW_STAGE.z, false, false, false, false)
    SetEntityHeading(ped, PREVIEW_STAGE.w)
    SetEntityAlpha(ped, 255, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    pcall(function() NetworkSetEntityInvisibleToNetwork(ped, true) end)

    RequestCollisionAtCoord(PREVIEW_STAGE.x, PREVIEW_STAGE.y, PREVIEW_STAGE.z)
    Wait(500)
    SetEntityCoords(ped, PREVIEW_STAGE.x, PREVIEW_STAGE.y, PREVIEW_STAGE.z, false, false, false, false)
    SetEntityHeading(ped, PREVIEW_STAGE.w)

    ClearPedTasksImmediately(ped)
    local scenario = IsPedMale(ped) and 'MP_LOBBY_STANDING_C' or 'MP_LOBBY_STANDING_G'
    TaskStartScenarioInPlace(ped, joaat(scenario), -1, true)
    FreezeEntityPosition(ped, false)
end

local function cloneAppliedPlayerForPreview()
    local sourcePed = PlayerPedId()
    local clone = ClonePed(sourcePed, PREVIEW_STAGE.w, false, false)
    if not clone or clone == 0 or not DoesEntityExist(clone) then
        print('[node7-charselect] ClonePed failed while creating the character preview.')
        return false
    end

    charPed = clone
    SetEntityAsMissionEntity(charPed, true, true)
    preparePreviewPed(charPed)
    hidePlayerAtOriginalStage()
    return true
end

local function applyAppearanceAndClone(skin, clothes)
    local selectedSkin = type(skin) == 'table' and skin or Config.DefaultAppearance.male
    local selectedClothes = type(clothes) == 'table' and clothes or {}

    local ok, err = pcall(function()
        exports['node7-appearance']:ApplySkin(selectedSkin, selectedClothes)
    end)
    if not ok then
        print(('[node7-charselect] node7-appearance ApplySkin failed: %s'):format(tostring(err)))
        return false
    end

    Wait(250)
    hidePlayerAtOriginalStage()
    return cloneAppliedPlayerForPreview()
end

local function showEmptyPreview()
    deletePreviewPed()
    local defaults = math.random(1, 2) == 1 and Config.DefaultAppearance.male or Config.DefaultAppearance.female
    applyAppearanceAndClone(defaults, {})
end

local function skyCam(enabled)
    if enabled then
        DoScreenFadeIn(1000)
        SetTimecycleModifier('hud_def_blur')
        SetTimecycleModifierStrength(1.0)

        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA')
        SetCamCoord(cam, CAMERA_START.x, CAMERA_START.y, CAMERA_START.z)
        SetCamRot(cam, CAMERA_START_ROT.x, CAMERA_START_ROT.y, CAMERA_START_ROT.z)
        SetCamFov(cam, 30.0)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 1, true, true)

        fixedCam = CreateCam('DEFAULT_SCRIPTED_CAMERA')
        SetCamCoord(fixedCam, CAMERA_END.x, CAMERA_END.y, CAMERA_END.z)
        SetCamRot(fixedCam, CAMERA_END_ROT.x, CAMERA_END_ROT.y, CAMERA_END_ROT.z)
        SetCamFov(fixedCam, 30.0)
        SetCamActive(fixedCam, true)
        SetCamActiveWithInterp(fixedCam, cam, 8000, true, true)
    else
        SetTimecycleModifier('default')
        RenderScriptCams(false, false, 1, true, true)
        if cam and DoesCamExist(cam) then DestroyCam(cam, true) end
        if fixedCam and DoesCamExist(fixedCam) then DestroyCam(fixedCam, true) end
        cam = nil
        fixedCam = nil
    end
end

local function openCharMenu(enabled, session)
    if not enabled then
        menuOpen = false
        isChoosing = false
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'ui', toggle = false })
        skyCam(false)
        return
    end

    Node7Core.Functions.TriggerCallback('node7-charselect:server:GetNumberOfCharacters', function(result)
        if session and session ~= selectionSession then return end

        menuOpen = true
        isChoosing = true
        SetNuiFocus(true, true)
        SendNUIMessage({
            action = 'ui',
            toggle = true,
            nChar = tonumber(result) or Config.DefaultNumberOfCharacters,
        })
        Wait(100)
        skyCam(true)
    end)
end

local function enterSelection()
    selectionSession = selectionSession + 1
    local session = selectionSession

    selectingChar = true
    isChoosing = true
    menuOpen = false
    loadingCharacter = false
    loadRequestPending = false
    previewToken = previewToken + 1

    setNativeLoadingScreen(false)
    setLoadingOverlay(false)
    pcall(ClearFocus)
    deletePreviewPed()
    skyCam(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'selectionReset' })

    -- Let the server save the real gameplay location before this client is moved
    -- to the fixed selector stage. This also safely logs out external flows.
    Node7Core.Functions.TriggerCallback('node7-charselect:server:prepareSelection', function()
        if session ~= selectionSession then return end

        DisplayRadar(false)
        DoScreenFadeOut(10)
        Wait(1000)

        if session ~= selectionSession then return end

        RequestImap(-1699673416)
        RequestImap(1679934574)
        RequestImap(183712523)
        GetInteriorAtCoords(PLAYER_STAGE.x, PLAYER_STAGE.y, PLAYER_STAGE.z)

        hidePlayerAtOriginalStage()
        Wait(1500)

        if session ~= selectionSession then return end

        ShutdownLoadingScreen()
        ShutdownLoadingScreenNui()
        nativeLoadingActive = false

        if Config.UseSelectionWeather and GetResourceState(Config.SelectionWeatherResource) == 'started' then
            pcall(function()
                exports[Config.SelectionWeatherResource]:setMyTime(Config.SelectionHour, 0, 0, 0, true)
                exports[Config.SelectionWeatherResource]:setMyWeather(Config.SelectionWeather, 10.0, false, false)
            end)
        end

        openCharMenu(true, session)
    end)
end

RegisterNetEvent('node7-charselect:client:chooseChar', enterSelection)

RegisterNetEvent('node7-charselect:client:closeNUI', function()
    menuOpen = false
    SetNuiFocus(false, false)
    isChoosing = false
end)

RegisterNUICallback('cDataPed', function(data, cb)
    if loadingCharacter or loadRequestPending then
        cb({ ok = false })
        return
    end

    previewToken = previewToken + 1
    local token = previewToken
    local character = data and data.cData

    deletePreviewPed()

    if not character or not character.citizenid then
        showEmptyPreview()
        cb({ ok = true })
        return
    end

    Node7Core.Functions.TriggerCallback('node7-charselect:server:getAppearance', function(appearance)
        if token ~= previewToken or loadingCharacter then return end

        local skin = type(appearance) == 'table' and appearance.skin or nil
        local clothes = type(appearance) == 'table' and appearance.clothes or nil
        if type(skin) ~= 'table' then
            local gender = character.charinfo and tonumber(character.charinfo.gender) or 0
            skin = gender == 1 and Config.DefaultAppearance.female or Config.DefaultAppearance.male
            clothes = {}
        end

        applyAppearanceAndClone(skin, clothes)
    end, character.citizenid)

    cb({ ok = true })
end)

RegisterNUICallback('closeUI', function(_, cb)
    openCharMenu(false)
    cb({ ok = true })
end)

RegisterNUICallback('disconnectButton', function(_, cb)
    deletePreviewPed()
    TriggerServerEvent('node7-charselect:server:disconnect')
    cb({ ok = true })
end)

RegisterNUICallback('selectCharacter', function(data, cb)
    if loadingCharacter or loadRequestPending then
        cb({ ok = false, message = 'A character is already loading.' })
        return
    end

    local character = data and data.cData
    if not character or not character.citizenid then
        notify('Select a valid character.', 'error')
        cb({ ok = false, message = 'Select a valid character.' })
        return
    end

    loadRequestPending = true
    selectingChar = false
    previewToken = previewToken + 1
    TriggerServerEvent('node7-charselect:server:loadUserData', character.citizenid)
    cb({ ok = true })
end)

RegisterNUICallback('setupCharacters', function(_, cb)
    Node7Core.Functions.TriggerCallback('node7-charselect:server:setupCharacters', function(result)
        SendNUIMessage({ action = 'setupCharacters', characters = result or {} })
    end)
    cb({ ok = true })
end)

RegisterNUICallback('removeBlur', function(_, cb)
    SetTimecycleModifier('default')
    cb({ ok = true })
end)

RegisterNUICallback('createNewCharacter', function(data, cb)
    if loadingCharacter or loadRequestPending then
        cb({ ok = false, message = 'A character is already loading.' })
        return
    end

    data = type(data) == 'table' and data or {}
    local slot = tonumber(data.cid)
    if not slot then
        cb({ ok = false, message = 'Invalid character slot.' })
        return
    end

    loadRequestPending = true
    TriggerServerEvent('node7-charselect:server:createCharacter', {
        cid = slot,
        firstname = data.firstname,
        lastname = data.lastname,
        birthdate = data.birthdate,
        nationality = data.nationality,
        gender = tonumber(data.gender) == 1 and 1 or 0,
    })
    cb({ ok = true })
end)

RegisterNUICallback('removeCharacter', function(data, cb)
    if loadingCharacter or loadRequestPending then
        cb({ ok = false, message = 'Wait for the current action to finish.' })
        return
    end

    if not Config.AllowDelete then
        cb({ ok = false, message = 'Character deletion is disabled.' })
        return
    end

    local citizenid = data and data.citizenid
    if not citizenid then
        cb({ ok = false, message = 'No character was selected.' })
        return
    end

    TriggerServerEvent('node7-charselect:server:deleteCharacter', citizenid)
    cb({ ok = true })
end)

RegisterNetEvent('node7-charselect:client:createResult', function(success, message)
    loadRequestPending = false
    if not success then
        notify(message or 'Character could not be created.', 'error')
        SendNUIMessage({ action = 'createResult', success = false, message = message })
        SetNuiFocus(true, true)
    end
end)

RegisterNetEvent('node7-charselect:client:deleteResult', function(success, message)
    notify(message or (success and 'Character deleted.' or 'Character could not be deleted.'), success and 'success' or 'error')
    SendNUIMessage({ action = 'deleteResult', success = success, message = message })
    if success then
        previewToken = previewToken + 1
        showEmptyPreview()
    end
end)

RegisterNetEvent('node7-charselect:client:prepareCharacterLoad', function(token, rawPosition, isNew)
    if loadingCharacter then return end

    loadingCharacter = true
    loadRequestPending = false
    menuOpen = false
    isChoosing = false
    selectingChar = false
    previewToken = previewToken + 1

    local position = decodePosition(rawPosition)
    SetNuiFocus(false, false)
    setLoadingOverlay(true, isNew == true)
    setNativeLoadingScreen(true, 'YOU ARE WAKING UP', isNew and 'Beginning your story' or 'Returning to your last location')
    deletePreviewPed()
    skyCam(false)
    prepareHiddenPlayerForSpawn(position)

    Wait(500)
    TriggerServerEvent('node7-charselect:server:readyForCharacterLoad', token)
end)

RegisterNetEvent('node7-charselect:client:spawnCharacter', function(playerData, appearance)
    menuOpen = false
    selectingChar = false
    isChoosing = false
    previewToken = previewToken + 1

    deletePreviewPed()
    SetNuiFocus(false, false)
    skyCam(false)

    local position = decodePosition(playerData and playerData.position)
    prepareHiddenPlayerForSpawn(position)

    local skin = type(appearance) == 'table' and appearance.skin or nil
    local clothes = type(appearance) == 'table' and appearance.clothes or nil
    if type(skin) == 'table' then
        local ok, err = pcall(function()
            exports['node7-appearance']:ApplySkin(skin, type(clothes) == 'table' and clothes or {})
        end)
        if not ok then
            print(('[node7-charselect] spawn appearance failed: %s'):format(tostring(err)))
        end
    end

    Wait(250)
    local ped = PlayerPedId()
    prepareHiddenPlayerForSpawn(position)
    waitForSpawnCollision(ped, position)

    ped = PlayerPedId()
    SetEntityCoords(ped, position.x, position.y, position.z, false, false, false, false)
    SetEntityHeading(ped, position.w)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetEntityAlpha(ped, 255, false)
    SetEntityVisible(ped, true, false)
    pcall(function() NetworkSetEntityInvisibleToNetwork(ped, false) end)

    DoScreenFadeIn(350)
    TriggerEvent('Node7Core:Client:OnPlayerLoaded')
    DisplayRadar(true)

    Wait(650)
    stopCharacterLoading(true)
end)

RegisterNetEvent('node7-charselect:client:serverError', function(message)
    loadRequestPending = false
    notify(message or 'Character action failed.', 'error')

    if loadingCharacter then
        stopCharacterLoading(false)
        CreateThread(function()
            Wait(150)
            enterSelection()
        end)
        return
    end

    SendNUIMessage({ action = 'characterLoadFailed', message = message })
    SendNUIMessage({ action = 'createResult', success = false, message = message })
    SetNuiFocus(true, true)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    deletePreviewPed()
    stopCharacterLoading(true)
    SetNuiFocus(false, false)
    skyCam(false)
    local ped = PlayerPedId()
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetEntityAlpha(ped, 255, false)
    SetEntityVisible(ped, true, false)
end)

CreateThread(function()
    repeat Wait(250) until NetworkIsPlayerActive(PlayerId())
    Wait(500)

    local hasLoadedCharacter = false
    pcall(function()
        local playerData = Node7Core.Functions.GetPlayerData()
        hasLoadedCharacter = type(playerData) == 'table' and playerData.citizenid ~= nil
    end)
    if not hasLoadedCharacter then
        enterSelection()
    end

    while true do
        if isChoosing then
            Citizen.InvokeNative(0xF1622CE88A1946FB)
            local coords = GetEntityCoords(PlayerPedId())
            DrawLightWithRange(coords.x + 10.0, coords.y, coords.z + 10.0, 255, 255, 255, 15.0, 15.0)
            Wait(0)
        else
            Wait(750)
        end
    end
end)
