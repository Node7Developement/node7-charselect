local Config = Node7CharSelectConfig or {}
local UiOpen = false
local SelectorCam = nil
local IsSpawning = false
local PedFrozen = false
local openMenu

local PendingRequests = {}
local RequestCounter = 0

local function setPedFrozen(ped, state)
    PedFrozen = state == true
    FreezeEntityPosition(ped, PedFrozen)
end

local function isPedFrozen()
    return PedFrozen == true
end

local function serverRequest(action, payload)
    RequestCounter = RequestCounter + 1
    if RequestCounter > 999999 then RequestCounter = 1 end

    local requestId = RequestCounter
    local p = promise.new()
    PendingRequests[requestId] = p

    TriggerServerEvent('node7-charselect:server:request', requestId, action, payload or {})

    SetTimeout(tonumber(Config.RequestTimeout) or 12000, function()
        if PendingRequests[requestId] then
            PendingRequests[requestId] = nil
            p:resolve({ ok = false, error = 'server request timed out' })
        end
    end)

    return Citizen.Await(p)
end

RegisterNetEvent('node7-charselect:client:response', function(requestId, result)
    requestId = tonumber(requestId)
    local p = requestId and PendingRequests[requestId]
    if not p then return end
    PendingRequests[requestId] = nil
    p:resolve(type(result) == 'table' and result or { ok = false, error = 'bad server response' })
end)


local function debugPrint(message)
    if Config.Debug then
        print(('^3[node7-charselect]^7 %s'):format(tostring(message)))
    end
end

local function getPosition(position)
    local fallback = Config.FirstSpawnPosition or { x = -277.76, y = 806.73, z = 119.38, w = 275.0 }
    position = type(position) == 'table' and position or fallback
    return {
        x = tonumber(position.x) or tonumber(fallback.x) or -277.76,
        y = tonumber(position.y) or tonumber(fallback.y) or 806.73,
        z = tonumber(position.z) or tonumber(fallback.z) or 119.38,
        w = tonumber(position.w or position.h or position.heading) or tonumber(fallback.w or fallback.h or fallback.heading) or 275.0,
        fallback = position.fallback == true,
        fallbackReason = position.fallbackReason
    }
end

local function resolveGround(position)
    if Config.GroundProbe == false or type(position) ~= 'table' then return position end

    local ok, found, groundZ = pcall(function()
        return GetGroundZFor_3dCoord(position.x, position.y, position.z + 50.0, false)
    end)

    if ok and found == true and type(groundZ) == 'number' and groundZ > -40.0 then
        position.z = groundZ + 0.05
    end

    return position
end

local function getCurrentPosition()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        w = GetEntityHeading(ped)
    }
end

local function normalizeGender(gender)
    gender = tostring(gender or ''):lower():match('^%s*(.-)%s*$')
    if gender == 'f' or gender == 'female' or gender == 'woman' then return 'female' end
    return 'male'
end

local function getGenderModel(gender)
    gender = normalizeGender(gender)
    local models = Config.GenderModels or {}
    local model = models[gender]
    if not model or model == '' then
        model = gender == 'female' and 'mp_female' or 'mp_male'
    end
    return gender, model
end

local function loadPedModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(tostring(model))

    local exists = true
    local okCd = pcall(function()
        exists = IsModelInCdimage(hash)
    end)
    if okCd and exists == false then return false, 'model_not_found' end

    RequestModel(hash)
    local timeout = GetGameTimer() + (tonumber(Config.ModelLoadTimeout) or 10000)
    while not HasModelLoaded(hash) and GetGameTimer() < timeout do
        RequestModel(hash)
        Wait(0)
    end

    if not HasModelLoaded(hash) then return false, 'model_load_timeout' end
    return true, hash
end

local function updatePedVariation(ped)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return end

    if Config.ApplyRandomOutfitVariation ~= false then
        -- 0x283978A15512B2FE = _SET_RANDOM_OUTFIT_VARIATION
        pcall(function()
            Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
        end)
    end

    -- 0xCC8CA3E88256E58F = _UPDATE_PED_VARIATION
    pcall(function()
        Citizen.InvokeNative(0xCC8CA3E88256E58F, ped, false, true, true, true, false)
    end)
end

local function repairPedVisibility(ped)
    if not ped or ped == 0 then return end

    SetEntityVisible(ped, true)
    SetEntityAlpha(ped, 255, false)
    ResetEntityAlpha(ped)
    updatePedVariation(ped)

    for _ = 1, 20 do
        if DoesEntityExist(ped) then
            SetEntityVisible(ped, true)
            SetEntityAlpha(ped, 255, false)
            ResetEntityAlpha(ped)
        end
        Wait(0)
    end
end

local function applyGenderModel(gender, keepCurrentPosition)
    local normalized, model = getGenderModel(gender)
    local ok, hashOrError = loadPedModel(model)
    if not ok then
        debugPrint(('Gender model failed for %s/%s: %s'):format(tostring(normalized), tostring(model), tostring(hashOrError)))
        return false, hashOrError
    end

    local oldPed = PlayerPedId()
    local coords = GetEntityCoords(oldPed)
    local heading = GetEntityHeading(oldPed)
    local frozen = isPedFrozen()
    local invincible = GetPlayerInvincible(PlayerId())

    local applied = pcall(function()
        SetPlayerModel(PlayerId(), hashOrError, false)
    end)
    if not applied then
        applied = pcall(function()
            SetPlayerModel(PlayerId(), hashOrError)
        end)
    end

    if not applied then return false, 'set_player_model_failed' end

    Wait(250)
    local ped = PlayerPedId()
    pcall(function() SetModelAsNoLongerNeeded(hashOrError) end)
    updatePedVariation(ped)
    repairPedVisibility(ped)

    if keepCurrentPosition then
        SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
        SetEntityHeading(ped, heading)
        repairPedVisibility(ped)
        SetEntityInvincible(ped, invincible)
        setPedFrozen(ped, frozen)
    else
        repairPedVisibility(ped)
    end

    LocalPlayer.state:set('node7GenderModel', normalized, true)
    return true, normalized
end

local SkinApplyPromise = nil

local function resolveSkinApply(status)
    if SkinApplyPromise then
        local p = SkinApplyPromise
        SkinApplyPromise = nil
        p:resolve(status or { ok = true })
    end
end

RegisterNetEvent('node7-skins:client:appliedSkin', function(data)
    resolveSkinApply({ ok = true, applied = true, data = data })
end)

RegisterNetEvent('node7-skins:client:noSkin', function()
    resolveSkinApply({ ok = true, applied = false, missing = true })
end)

local function getResultPlayer(result)
    return type(result) == 'table' and type(result.player) == 'table' and result.player or nil
end

local function getPlayerGender(player)
    local charinfo = type(player) == 'table' and type(player.charinfo) == 'table' and player.charinfo or nil
    return charinfo and (charinfo.gender or charinfo.sex) or nil
end



local function waitForSkinApply(player, openIfMissing)
    local skinConfig = Config.Skins or {}
    if skinConfig.enabled == false then
        return { ok = true, skipped = true, reason = 'disabled' }
    end

    local resource = skinConfig.resource or 'node7-skins'
    if GetResourceState(resource) ~= 'started' then
        if skinConfig.FallbackToGenderModelWhenMissing ~= false then
            applyGenderModel(getPlayerGender(player), true)
        end
        return { ok = true, skipped = true, reason = 'resource_not_started' }
    end

    if SkinApplyPromise then
        resolveSkinApply({ ok = false, cancelled = true })
    end

    local p = promise.new()
    SkinApplyPromise = p

    TriggerEvent(skinConfig.clientEvent or 'node7-skins:client:loadSkin', openIfMissing == true)

    SetTimeout(tonumber(skinConfig.timeout) or tonumber(skinConfig.waitMs) or 5000, function()
        if SkinApplyPromise == p then
            SkinApplyPromise = nil
            p:resolve({ ok = false, timeout = true })
        end
    end)

    local result = Citizen.Await(p)
    result = type(result) == 'table' and result or { ok = false }

    if (result.missing or result.timeout or result.cancelled) and skinConfig.FallbackToGenderModelWhenMissing ~= false then
        applyGenderModel(getPlayerGender(player), true)
    end

    return result
end

local function applyPlayerModelFromResult(result, keepCurrentPosition)
    local player = getResultPlayer(result)
    local skinConfig = Config.Skins or {}

    if skinConfig.applyBeforeSpawn ~= false then
        local openIfMissing = false
        if (result.created == true or result.setup == true) and skinConfig.openCreatorOnFirstCreate == true then
            openIfMissing = true
        end

        local skinResult = waitForSkinApply(player, openIfMissing)
        if skinResult and skinResult.applied then
            return true, 'skin_applied'
        end
    end

    if skinConfig.FallbackToGenderModelWhenMissing == false then
        return true, 'skin_skipped_no_model_swap'
    end

    return applyGenderModel(getPlayerGender(player), keepCurrentPosition)
end

local function applyPostSpawnLayers(_result)
    local clothingConfig = Config.Clothing or Config.TailorShops or {}
    if clothingConfig.enabled == false then return end

    local delay = tonumber(clothingConfig.delayAfterSpawn) or 750
    SetTimeout(delay, function()
        local resources = clothingConfig.resources
        if type(resources) == 'table' then
            for _, entry in ipairs(resources) do
                local resource = entry and entry.resource
                local event = entry and entry.event
                if resource and event and GetResourceState(resource) == 'started' then
                    TriggerEvent(event)
                    return
                end
            end
        end

        local resource = clothingConfig.resource or 'node7-clothing'
        if GetResourceState(resource) == 'started' then
            TriggerEvent(clothingConfig.clientEvent or 'node7-clothing:client:loadSavedClothing')
        end
    end)
end

local function hideRadar()
    DisplayRadar(false)
end

local function createSelectorCamera()
    if not Config.Camera or Config.Camera.enabled == false then return end
    if SelectorCam then return end

    local cam = Config.Camera
    SelectorCam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamCoord(SelectorCam, cam.x or -281.55, cam.y or 812.10, cam.z or 121.25)
    SetCamRot(SelectorCam, cam.rotationX or -8.0, cam.rotationY or 0.0, cam.rotationZ or 205.0, 2)
    SetCamFov(SelectorCam, cam.fov or 45.0)
    SetCamActive(SelectorCam, true)
    RenderScriptCams(true, true, 500, true, true)
end

local function destroySelectorCamera()
    if SelectorCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(SelectorCam, false)
        SelectorCam = nil
    end
end


local ActiveSceneIndex = tonumber(Config.CharScene) or tonumber(Config.DefaultCharScene) or 4

local function getSceneSlot(slot)
    slot = tonumber(slot) or 1
    local scenes = Config.CharScenes
    if type(scenes) ~= 'table' then return nil end
    local sceneSet = scenes[ActiveSceneIndex] or scenes[1]
    if type(sceneSet) ~= 'table' then return nil end
    return sceneSet[slot], sceneSet
end

local function applySceneSlot(slot)
    local charscene, sceneSet = getSceneSlot(slot)
    if type(charscene) ~= 'table' then return false end

    local ped = PlayerPedId()
    if charscene.PedCoord then
        ClearPedTasksImmediately(ped)
        SetEntityCoords(ped, charscene.PedCoord.x, charscene.PedCoord.y, charscene.PedCoord.z, false, false, false, false)
        SetEntityHeading(ped, charscene.PedCoord.w or 0.0)
        setPedFrozen(ped, true)
        SetEntityInvincible(ped, true)
        repairPedVisibility(ped)
    elseif sceneSet and sceneSet.MainPedCoord then
        SetEntityCoords(ped, sceneSet.MainPedCoord.x, sceneSet.MainPedCoord.y, sceneSet.MainPedCoord.z, false, false, false, false)
    end

    local scenario = charscene.Scenario
    if not scenario then
        if IsPedMale(ped) then
            scenario = charscene.ScenarioMale
        else
            scenario = charscene.ScenarioFemale
        end
    end
    if scenario then
        pcall(function()
            TaskStartScenarioInPlace(ped, scenario, -1, true, false, false, false)
        end)
    end

    if SelectorCam and charscene.CamCoord then
        SetCamCoord(SelectorCam, charscene.CamCoord.x, charscene.CamCoord.y, charscene.CamCoord.z)
        SetCamRot(SelectorCam, 0.0, 0.0, charscene.CamCoord.w or 0.0, 2)
        if charscene.PointCam then
            PointCamAtCoord(SelectorCam, charscene.PointCam.x, charscene.PointCam.y, charscene.PointCam.z)
        elseif charscene.PedCoord then
            PointCamAtCoord(SelectorCam, charscene.PedCoord.x, charscene.PedCoord.y, charscene.PedCoord.z + 1.0)
        end
        if charscene.CamFov then SetCamFov(SelectorCam, charscene.CamFov) end
    end

    return true
end

local function prepareSelectorScene()
    local ped = PlayerPedId()
    local pos = getPosition(Config.SelectorPosition)

    if Config.PreviewPed == nil or Config.PreviewPed.enabled ~= false then
        applyGenderModel(Config.PreviewPed.defaultGender or 'male', false)
        ped = PlayerPedId()
    end

    setPedFrozen(ped, true)
    if Config.PreviewPed == nil or Config.PreviewPed.visible ~= false then
        repairPedVisibility(ped)
    else
        SetEntityVisible(ped, false)
    end
    SetEntityInvincible(ped, true)
    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(ped, pos.w)
    createSelectorCamera()
    applySceneSlot(1)
    hideRadar()
end

local function closeUiOnly()
    UiOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hide' })
end

local function spawnAt(position)
    if IsSpawning then return end
    IsSpawning = true

    local ped = PlayerPedId()
    local pos = resolveGround(getPosition(position))

    DoScreenFadeOut(350)
    local timeout = GetGameTimer() + 3500
    while not IsScreenFadedOut() and GetGameTimer() < timeout do Wait(0) end

    closeUiOnly()
    destroySelectorCamera()

    RequestCollisionAtCoord(pos.x, pos.y, pos.z)
    SetEntityCoords(ped, pos.x, pos.y, pos.z + 0.05, false, false, false, false)
    SetEntityHeading(ped, pos.w)
    repairPedVisibility(ped)
    SetEntityInvincible(ped, false)
    setPedFrozen(ped, true)

    local collisionTimeout = GetGameTimer() + 6000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < collisionTimeout do
        RequestCollisionAtCoord(pos.x, pos.y, pos.z)
        Wait(0)
    end

    setPedFrozen(ped, false)
    DisplayRadar(true)

    if pos.fallback and pos.fallbackReason then
        TriggerEvent('chat:addMessage', {
            color = { 212, 175, 55 },
            args = { 'Node7', pos.fallbackReason }
        })
    end

    DoScreenFadeIn(600)
    TriggerEvent('node7-charselect:client:spawned', pos)
    TriggerEvent('node7-charselect:client:characterLoaded', pos)
    IsSpawning = false
end


local function finishLoadedCharacter(result, position)
    CreateThread(function()
        result = type(result) == 'table' and result or {}
        position = type(position) == 'table' and position or result.position

        local ok, err = pcall(function()
            applyPlayerModelFromResult(result, true)
            spawnAt(position)
            -- Clothing is intentionally not opened or loaded by charselect.
        end)

        if not ok then
            print(('^1[node7-charselect]^7 final spawn failed: %s'):format(tostring(err)))
            IsSpawning = false
            closeUiOnly()
            destroySelectorCamera()
            local ped = PlayerPedId()
            repairPedVisibility(ped)
            SetEntityInvincible(ped, false)
            setPedFrozen(ped, false)
            DisplayRadar(true)
            DoScreenFadeIn(350)
        end
    end)
end


local function handleLoadedCharacter(result)
    if not result or result.ok ~= true then return end
    finishLoadedCharacter(result, result.position or Config.FirstSpawnPosition)
end

local function refreshCharacters()
    local result = serverRequest('getCharacters', {})
    result = type(result) == 'table' and result or { ok = false, error = 'no response from server' }
    SendNUIMessage({ action = 'setCharacters', data = result, type = 1, list = result })
    return result
end

function openMenu(force)
    if UiOpen and not force then return end

    UiOpen = true
    SetNuiFocus(true, true)
    prepareSelectorScene()
    SendNUIMessage({ action = 'show', labels = Config.DefaultLabels or {} })
    refreshCharacters()
end

RegisterNetEvent('node7-charselect:client:open', function()
    openMenu(true)
end)

-- Compatibility for older NODE7 resources still calling the old multicharacter name.
RegisterNetEvent('node7-multicharacter:client:open', function()
    openMenu(true)
end)

RegisterNUICallback('ready', function(_, cb)
    cb({ ok = true })
end)

RegisterNUICallback('refresh', function(_, cb)
    local result = refreshCharacters()
    cb(result)
end)

RegisterNUICallback('play', function(data, cb)
    local result = serverRequest('playCharacter', data or {})
    result = type(result) == 'table' and result or { ok = false, error = 'no response from server' }
    cb(result)
    if result.ok then
        CreateThread(function()
            Wait(0)
            handleLoadedCharacter(result)
        end)
    end
end)

RegisterNUICallback('create', function(data, cb)
    local result = serverRequest('createCharacter', data or {})
    result = type(result) == 'table' and result or { ok = false, error = 'no response from server' }
    cb(result)
    if result.ok then
        CreateThread(function()
            Wait(0)
            handleLoadedCharacter(result)
        end)
    end
end)

RegisterNUICallback('finishSetup', function(data, cb)
    local result = serverRequest('finishSetup', data or {})
    result = type(result) == 'table' and result or { ok = false, error = 'no response from server' }
    cb(result)
    if result.ok then
        CreateThread(function()
            Wait(0)
            handleLoadedCharacter(result)
        end)
    end
end)

RegisterNUICallback('delete', function(data, cb)
    local result = serverRequest('deleteCharacter', data or {})
    result = type(result) == 'table' and result or { ok = false, error = 'no response from server' }
    if result.ok then refreshCharacters() end
    cb(result)
end)

RegisterNUICallback('focus', function(_, cb)
    SetNuiFocus(true, true)
    cb({ ok = true })
end)

RegisterNUICallback('previewGender', function(data, cb)
    if Config.PreviewPed and Config.PreviewPed.enabled == false then
        cb({ ok = true, skipped = true })
        return
    end

    data = type(data) == 'table' and data or {}
    local ok, result = applyGenderModel(data.gender, true)
    local ped = PlayerPedId()
    local pos = getPosition(Config.SelectorPosition)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)
    SetEntityHeading(ped, pos.w)
    setPedFrozen(ped, true)
    SetEntityInvincible(ped, true)
    if Config.PreviewPed == nil or Config.PreviewPed.visible ~= false then
        repairPedVisibility(ped)
    else
        SetEntityVisible(ped, false)
    end
    cb({ ok = ok == true, result = result })
end)

RegisterNUICallback('previewSlot', function(data, cb)
    data = type(data) == 'table' and data or {}
    local ok = applySceneSlot(tonumber(data.slot) or 1)
    cb({ ok = ok == true })
end)

RegisterNUICallback('cancelNew', function(_, cb)
    cb({ ok = true })
end)

local function logoutCharacter()
    if UiOpen or IsSpawning then return end

    local result = serverRequest('logout', { position = getCurrentPosition() })
    result = type(result) == 'table' and result or { ok = false, error = 'no response from server' }

    if not result.ok then
        TriggerEvent('chat:addMessage', {
            color = { 255, 90, 90 },
            args = { 'Node7', result.error or 'Logout failed' }
        })
        return
    end

    TriggerEvent('chat:addMessage', {
        color = { 212, 175, 55 },
        args = { 'Node7', 'Logged out. Last location saved.' }
    })

    openMenu(true)
end

RegisterNetEvent('node7-charselect:client:logout', logoutCharacter)
RegisterNetEvent('node7-multicharacter:client:logout', logoutCharacter)

CreateThread(function()
    while not NetworkIsSessionStarted() or not NetworkIsPlayerActive(PlayerId()) do
        Wait(250)
    end

    Wait(tonumber(Config.OpenDelay) or 1500)
    openMenu(false)
end)

if Config.ReopenCommand and Config.ReopenCommand ~= '' then
    RegisterCommand(Config.ReopenCommand, function()
        openMenu(true)
    end, false)
end

if type(Config.LegacyReopenCommands) == 'table' then
    for _, command in ipairs(Config.LegacyReopenCommands) do
        if command and command ~= '' and command ~= Config.ReopenCommand then
            RegisterCommand(command, function()
                openMenu(true)
            end, false)
        end
    end
end

if Config.LogoutCommand and Config.LogoutCommand ~= '' then
    RegisterCommand(Config.LogoutCommand, logoutCharacter, false)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
    destroySelectorCamera()
    local ped = PlayerPedId()
    repairPedVisibility(ped)
    SetEntityInvincible(ped, false)
    setPedFrozen(ped, false)
    DisplayRadar(true)
end)
