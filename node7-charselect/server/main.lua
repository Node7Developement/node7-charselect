local Node7Core = exports['node7-core']:GetCoreObject()
local RESOURCE_NAME = GetCurrentResourceName()

local pendingLoads = {}
local selectionRequests = {}
local SELECTOR_PLAYER_STAGE = { x = 1542.79, y = 1187.29, z = 283.18 }
local SELECTOR_PREVIEW_STAGE = { x = 1544.10, y = 1187.65, z = 283.18 }

local function notify(source, message, notifyType)
    Node7Core.Functions.Notify(source, {
        title = 'NODE7 CHARSELECT',
        description = tostring(message or 'Character action failed.'),
        type = notifyType or 'info',
        duration = 5000,
    })
end

local function decode(value, fallback)
    if type(value) == 'table' then return value end
    if type(value) ~= 'string' or value == '' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    return ok and decoded or fallback
end

local function trim(value)
    return tostring(value or ''):gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
end

local function normalizeName(value, minimum, maximum)
    value = trim(value)
    if #value < minimum or #value > maximum then return nil end
    if not value:match("^[%a][%a%-%' ]*$") then return nil end
    return value:gsub("(%a)([%w']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

local function validBirthdate(value)
    value = trim(value)
    local year, month, day = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    if not year or not month or not day then return nil end
    if year < Config.Identity.minimumBirthYear or year > Config.Identity.maximumBirthYear then return nil end
    if month < 1 or month > 12 or day < 1 or day > 31 then return nil end

    local days = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0) then days[2] = 29 end
    if day > days[month] then return nil end

    return ('%04d-%02d-%02d'):format(year, month, day)
end

local function getLicense(source)
    return Node7Core.Functions.GetIdentifier(source, 'license') or GetPlayerIdentifierByType(source, 'license')
end

local function normalizePosition(position)
    position = decode(position, Config.DefaultSpawn)
    position = type(position) == 'table' and position or Config.DefaultSpawn

    return {
        x = tonumber(position.x or position[1]) or Config.DefaultSpawn.x,
        y = tonumber(position.y or position[2]) or Config.DefaultSpawn.y,
        z = tonumber(position.z or position[3]) or Config.DefaultSpawn.z,
        w = tonumber(position.w or position.h or position.heading or position[4]) or Config.DefaultSpawn.w,
    }
end

local function distanceSquared(position, target)
    local dx = position.x - target.x
    local dy = position.y - target.y
    local dz = position.z - target.z
    return (dx * dx) + (dy * dy) + (dz * dz)
end

local function isSelectorPosition(position)
    local radiusSquared = 25.0 * 25.0
    return distanceSquared(position, SELECTOR_PLAYER_STAGE) <= radiusSquared
        or distanceSquared(position, SELECTOR_PREVIEW_STAGE) <= radiusSquared
end

local function sanitizeStoredPosition(position)
    local normalized = normalizePosition(position)
    if isSelectorPosition(normalized) then
        return normalizePosition(Config.DefaultSpawn), true
    end
    return normalized, false
end

local function compactCharacter(row)
    row.charinfo = decode(row.charinfo, {})
    row.money = decode(row.money, {})
    row.job = decode(row.job, { name = 'unemployed', label = 'Civilian', grade = { level = 0 } })
    row.gang = decode(row.gang, { name = 'none', label = 'No Gang Affiliation', grade = { level = 0 } })
    row.metadata = decode(row.metadata, {})
    row.position = normalizePosition(row.position)
    row.cid = tonumber(row.cid or row.slot) or 1
    row.slot = tonumber(row.slot or row.cid) or row.cid
    row.job.label = row.job.label or row.job.name or 'Civilian'
    row.gang.label = row.gang.label or row.gang.name or 'No Gang Affiliation'
    row.money.cash = tonumber(row.money.cash) or 0
    row.money.bank = tonumber(row.money.bank) or 0
    row.money.bloodmoney = tonumber(row.money.bloodmoney) or 0
    return row
end

local function getCharacters(source)
    local license = getLicense(source)
    if not license then return {} end
    local rows = MySQL.query.await('SELECT * FROM players WHERE license = ? ORDER BY slot ASC, cid ASC', { license }) or {}
    local characters = {}
    for _, row in ipairs(rows) do
        characters[#characters + 1] = compactCharacter(row)
    end
    return characters
end

local function characterOwnedBy(source, citizenid)
    local license = getLicense(source)
    if not license or not citizenid then return false end
    return MySQL.scalar.await('SELECT license FROM players WHERE citizenid = ? LIMIT 1', { citizenid }) == license
end

local function getAppearance(citizenid)
    if GetResourceState('node7-appearance') ~= 'started' then return nil end
    local ok, appearance = pcall(function()
        return exports['node7-appearance']:GetAppearance(citizenid)
    end)
    return ok and type(appearance) == 'table' and appearance or nil
end

local function saveDefaultAppearance(citizenid, gender)
    if GetResourceState('node7-appearance') ~= 'started' then return false end
    local skin = gender == 1 and Config.DefaultAppearance.female or Config.DefaultAppearance.male
    local okSkin, skinSaved = pcall(function()
        return exports['node7-appearance']:SaveSkin(citizenid, skin)
    end)
    local okClothes, clothesSaved = pcall(function()
        return exports['node7-appearance']:SaveClothes(citizenid, {})
    end)
    return okSkin and skinSaved ~= false and okClothes and clothesSaved ~= false
end

local function getCharacterLimit(source)
    local license = getLicense(source)
    for _, entry in ipairs(Config.PlayersNumberOfCharacters or {}) do
        if entry.license == license then
            return math.max(1, math.min(tonumber(entry.numberOfChars) or Config.DefaultNumberOfCharacters, 5))
        end
    end
    return math.max(1, math.min(tonumber(Config.DefaultNumberOfCharacters) or 5, 5))
end

local function createLoadToken(source)
    return ('%d:%d:%d'):format(source, os.time(), math.random(100000, 999999))
end

local function failPendingLoad(source, message)
    pendingLoads[source] = nil
    TriggerClientEvent('node7-charselect:client:serverError', source, message)
end

local function moveServerPedToPosition(source, position)
    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return end

    pcall(function()
        SetEntityCoords(ped, position.x, position.y, position.z, false, false, false, false)
        SetEntityHeading(ped, position.w)
    end)
end

local function beginCharacterLoad(source, pending)
    local active = pendingLoads[source]
    if active and os.time() - (active.createdAt or 0) <= 30 then
        TriggerClientEvent('node7-charselect:client:serverError', source, 'A character is already loading.')
        return false
    end
    pendingLoads[source] = nil

    pending.token = createLoadToken(source)
    pending.createdAt = os.time()
    pendingLoads[source] = pending
    TriggerClientEvent(
        'node7-charselect:client:prepareCharacterLoad',
        source,
        pending.token,
        pending.position,
        pending.kind == 'new'
    )
    return true
end

local function saveExactLogoutPosition(source, player)
    if not player or not player.PlayerData or not player.PlayerData.citizenid then return end

    local ped = GetPlayerPed(source)
    if not ped or ped <= 0 then return end

    local coords = GetEntityCoords(ped)
    local position = {
        x = tonumber(coords.x) or Config.DefaultSpawn.x,
        y = tonumber(coords.y) or Config.DefaultSpawn.y,
        z = tonumber(coords.z) or Config.DefaultSpawn.z,
        w = tonumber(GetEntityHeading(ped)) or Config.DefaultSpawn.w,
    }

    -- Never save the selector lobby as a gameplay location.
    if isSelectorPosition(position) then return end

    player.PlayerData.position = position
    if player.Functions and player.Functions.Save then
        player.Functions.Save()
    end

    MySQL.update.await('UPDATE players SET position = ? WHERE citizenid = ? AND license = ?', {
        json.encode(position),
        player.PlayerData.citizenid,
        getLicense(source),
    })
end

Node7Core.Functions.CreateCallback('node7-charselect:server:GetNumberOfCharacters', function(source, cb)
    cb(getCharacterLimit(source))
end)

local function prepareSelection(source)
    pendingLoads[source] = nil
    local player = Node7Core.Functions.GetPlayer(source)
    if player then
        saveExactLogoutPosition(source, player)
        Node7Core.Player.Logout(source)
        Wait(250)
    end
end

Node7Core.Functions.CreateCallback('node7-charselect:server:prepareSelection', function(source, cb)
    prepareSelection(source)
    cb(true)
end)

RegisterNetEvent('node7-charselect:server:requestSelection', function(requestId)
    local source = source
    requestId = trim(requestId)
    if requestId == '' then return end

    local existing = selectionRequests[source]
    if existing and existing.id == requestId then
        if existing.ready then
            TriggerClientEvent('node7-charselect:client:selectionPrepared', source, requestId)
        end
        return
    end

    selectionRequests[source] = { id = requestId, ready = false }
    prepareSelection(source)

    local current = selectionRequests[source]
    if not current or current.id ~= requestId or not GetPlayerName(source) then return end
    current.ready = true
    TriggerClientEvent('node7-charselect:client:selectionPrepared', source, requestId)
end)

Node7Core.Functions.CreateCallback('node7-charselect:server:setupCharacters', function(source, cb)
    cb(getCharacters(source))
end)

Node7Core.Functions.CreateCallback('node7-charselect:server:getAppearance', function(source, cb, citizenid)
    citizenid = trim(citizenid)
    if citizenid == '' or not characterOwnedBy(source, citizenid) then
        cb(nil)
        return
    end
    cb(getAppearance(citizenid))
end)

RegisterNetEvent('node7-charselect:server:disconnect', function()
    pendingLoads[source] = nil
    DropPlayer(source, Config.DisconnectMessage)
end)

RegisterNetEvent('node7-charselect:server:loadUserData', function(citizenid)
    local source = source
    citizenid = trim(citizenid)

    if citizenid == '' or not characterOwnedBy(source, citizenid) then
        TriggerClientEvent('node7-charselect:client:serverError', source, 'Character ownership validation failed.')
        return
    end

    local storedRow = MySQL.single.await('SELECT position FROM players WHERE citizenid = ? AND license = ? LIMIT 1', {
        citizenid,
        getLicense(source),
    })
    local storedPosition, repaired = sanitizeStoredPosition(storedRow and storedRow.position or Config.DefaultSpawn)

    if repaired then
        MySQL.update.await('UPDATE players SET position = ? WHERE citizenid = ? AND license = ?', {
            json.encode(storedPosition),
            citizenid,
            getLicense(source),
        })
    end

    beginCharacterLoad(source, {
        kind = 'existing',
        citizenid = citizenid,
        position = storedPosition,
    })
end)

RegisterNetEvent('node7-charselect:server:createCharacter', function(data)
    local source = source
    data = type(data) == 'table' and data or {}
    local slot = tonumber(data.cid)

    if pendingLoads[source] then
        TriggerClientEvent('node7-charselect:client:createResult', source, false, 'A character is already loading.')
        return
    end

    if not slot or slot < 1 or slot > getCharacterLimit(source) then
        TriggerClientEvent('node7-charselect:client:createResult', source, false, 'Invalid character slot.')
        return
    end

    local license = getLicense(source)
    local occupied = MySQL.scalar.await('SELECT citizenid FROM players WHERE license = ? AND slot = ? LIMIT 1', { license, slot })
    if occupied then
        TriggerClientEvent('node7-charselect:client:createResult', source, false, 'That character slot is already occupied.')
        return
    end

    local firstname = normalizeName(data.firstname, Config.Identity.firstNameMin, Config.Identity.firstNameMax)
    local lastname = normalizeName(data.lastname, Config.Identity.lastNameMin, Config.Identity.lastNameMax)
    local birthdate = validBirthdate(data.birthdate)
    local nationality = trim(data.nationality):sub(1, Config.Identity.nationalityMax)
    local gender = tonumber(data.gender) == 1 and 1 or 0

    if not firstname then
        TriggerClientEvent('node7-charselect:client:createResult', source, false, 'Enter a valid first name.')
        return
    end
    if not lastname then
        TriggerClientEvent('node7-charselect:client:createResult', source, false, 'Enter a valid last name.')
        return
    end
    if not birthdate then
        TriggerClientEvent('node7-charselect:client:createResult', source, false, 'Birthdate must be a real date using YYYY-MM-DD.')
        return
    end
    if nationality == '' then
        TriggerClientEvent('node7-charselect:client:createResult', source, false, 'Enter a nationality.')
        return
    end

    local spawnPosition = normalizePosition(Config.DefaultSpawn)
    beginCharacterLoad(source, {
        kind = 'new',
        position = spawnPosition,
        license = license,
        slot = slot,
        gender = gender,
        firstname = firstname,
        lastname = lastname,
        newData = {
            cid = slot,
            slot = slot,
            charinfo = {
                firstname = firstname,
                lastname = lastname,
                birthdate = birthdate,
                gender = gender,
                nationality = nationality,
            },
            position = spawnPosition,
        },
    })
end)

RegisterNetEvent('node7-charselect:server:readyForCharacterLoad', function(token)
    local source = source
    local pending = pendingLoads[source]

    if not pending or pending.token ~= tostring(token or '') then
        TriggerClientEvent('node7-charselect:client:serverError', source, 'The character loading request expired.')
        return
    end

    if os.time() - pending.createdAt > 30 then
        failPendingLoad(source, 'The character loading request timed out.')
        return
    end

    pendingLoads[source] = nil
    moveServerPedToPosition(source, pending.position)
    Wait(350)

    local currentPlayer = Node7Core.Functions.GetPlayer(source)
    if currentPlayer then
        Node7Core.Player.Logout(source)
        Wait(250)
    end

    if pending.kind == 'existing' then
        if not characterOwnedBy(source, pending.citizenid) then
            TriggerClientEvent('node7-charselect:client:serverError', source, 'Character ownership validation failed.')
            return
        end

        if not Node7Core.Player.Login(source, pending.citizenid) then
            TriggerClientEvent('node7-charselect:client:serverError', source, 'Character could not be loaded.')
            return
        end

        local player = Node7Core.Functions.GetPlayer(source)
        if not player or not player.PlayerData then
            TriggerClientEvent('node7-charselect:client:serverError', source, 'Character data was unavailable after login.')
            return
        end

        player.PlayerData.position = pending.position
        TriggerClientEvent('node7-charselect:client:closeNUI', source)
        TriggerClientEvent('node7-charselect:client:spawnCharacter', source, player.PlayerData, getAppearance(pending.citizenid))
        return
    end

    local occupied = MySQL.scalar.await('SELECT citizenid FROM players WHERE license = ? AND slot = ? LIMIT 1', {
        pending.license,
        pending.slot,
    })
    if occupied then
        TriggerClientEvent('node7-charselect:client:serverError', source, 'That character slot is already occupied.')
        return
    end

    if not Node7Core.Player.Login(source, false, pending.newData) then
        TriggerClientEvent('node7-charselect:client:serverError', source, 'The character could not be created.')
        return
    end

    local player = Node7Core.Functions.GetPlayer(source)
    local citizenid = player and player.PlayerData and player.PlayerData.citizenid
    if not citizenid then
        Node7Core.Player.Logout(source)
        TriggerClientEvent('node7-charselect:client:serverError', source, 'The new character ID was not created.')
        return
    end

    if not saveDefaultAppearance(citizenid, pending.gender) then
        Node7Core.Player.Logout(source)
        MySQL.query.await('DELETE FROM players WHERE citizenid = ? AND license = ?', { citizenid, pending.license })
        TriggerClientEvent('node7-charselect:client:serverError', source, 'The default NODE7 appearance could not be saved.')
        return
    end

    player.PlayerData.position = pending.position
    MySQL.update.await('UPDATE players SET position = ? WHERE citizenid = ? AND license = ?', {
        json.encode(pending.position),
        citizenid,
        pending.license,
    })

    TriggerClientEvent('node7-charselect:client:closeNUI', source)
    TriggerClientEvent('node7-charselect:client:spawnCharacter', source, player.PlayerData, getAppearance(citizenid))
    notify(source, ('Welcome, %s %s. Visit a clothing store to customize your character.'):format(pending.firstname, pending.lastname), 'success')
end)

local function tableExists(tableName)
    local result = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = DATABASE() AND table_name = ?
    ]], { tableName })
    return tonumber(result) and tonumber(result) > 0
end

RegisterNetEvent('node7-charselect:server:deleteCharacter', function(citizenid)
    local source = source
    citizenid = trim(citizenid)

    if not Config.AllowDelete then
        TriggerClientEvent('node7-charselect:client:deleteResult', source, false, 'Character deletion is disabled.')
        return
    end
    if citizenid == '' or not characterOwnedBy(source, citizenid) then
        TriggerClientEvent('node7-charselect:client:deleteResult', source, false, 'Character ownership validation failed.')
        return
    end

    local relatedTables = {
        'player_clothing_outfits',
        'player_clothing',
        'player_skins',
        'playeroutfit',
        'playerskins',
        'player_weapons',
        'address_book',
        'telegrams',
    }

    for _, tableName in ipairs(relatedTables) do
        if tableExists(tableName) then
            MySQL.query.await(('DELETE FROM `%s` WHERE citizenid = ?'):format(tableName), { citizenid })
        end
    end

    local deleted = MySQL.update.await('DELETE FROM players WHERE citizenid = ? AND license = ?', {
        citizenid,
        getLicense(source),
    })
    local success = tonumber(deleted) and tonumber(deleted) > 0
    TriggerClientEvent(
        'node7-charselect:client:deleteResult',
        source,
        success,
        success and 'Character deleted.' or 'Character could not be deleted.'
    )
end)

RegisterCommand('logout', function(source)
    if source <= 0 then return end

    pendingLoads[source] = nil
    local player = Node7Core.Functions.GetPlayer(source)
    if player then
        saveExactLogoutPosition(source, player)
        Node7Core.Player.Logout(source)
    end

    TriggerClientEvent('node7-charselect:client:chooseChar', source)
end, false)

AddEventHandler('playerDropped', function()
    pendingLoads[source] = nil
    selectionRequests[source] = nil
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= RESOURCE_NAME then return end
    CreateThread(function()
        Wait(1000)
        for _, playerId in ipairs(GetPlayers()) do
            TriggerClientEvent('node7-charselect:client:forceSelectionAfterRestart', tonumber(playerId))
        end
    end)
end)

print(('[%s] started v5.4.0'):format(RESOURCE_NAME))
