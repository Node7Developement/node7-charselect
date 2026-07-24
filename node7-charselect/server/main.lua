local RESOURCE = GetCurrentResourceName()
local newlyCreatedBySource = {}

local function cfg()
    return Node7CharselectConfig or {}
end

local function debugPrint(message)
    if cfg().Debug then
        print(('^3[node7-charselect]^7 %s'):format(tostring(message)))
    end
end

local function getCore()
    if GetResourceState('node7-core') ~= 'started' then return nil end
    local ok, core = pcall(function()
        return exports['node7-core']:GetCoreObject()
    end)
    if ok and type(core) == 'table' then return core end
    return nil
end

local function playersResourceReady()
    return GetResourceState('node7-players') == 'started'
end

local function callPlayers(exportName, ...)
    if not playersResourceReady() then return false, 'node7_players_not_started' end
    local exportTable = exports['node7-players']
    if not exportTable or not exportTable[exportName] then return false, ('missing_export_%s'):format(exportName) end
    local ok, result, extra = pcall(exportTable[exportName], ...)
    if not ok then return false, result end
    return result, extra
end

local function decodeJson(value, fallback)
    if type(value) == 'table' then return value end
    if value == nil or value == '' then return fallback end
    if type(value) ~= 'string' then return fallback end
    local ok, decoded = pcall(json.decode, value)
    if ok and decoded ~= nil then return decoded end
    return fallback
end

local function encodeJson(value, fallback)
    local ok, encoded = pcall(json.encode, value or fallback or {})
    if ok and encoded then return encoded end
    return '{}'
end

local function safeDb(fn, fallback)
    local ok, result = pcall(fn)
    if ok then return result end
    print(('^1[node7-charselect]^7 database/core operation failed: %s'):format(tostring(result)))
    return fallback
end

local function getDefaultMoney(core)
    local defaults = (((core or {}).Config or {}).Money or {}).MoneyTypes or nil
    local money = {}
    if type(defaults) == 'table' then
        for name, amount in pairs(defaults) do money[name] = tonumber(amount) or 0 end
    end
    if next(money) == nil then money = { cash = 50, bank = 0, bloodmoney = 0 } end
    return money
end

local function getDefaultJob(core)
    local jobs = (((core or {}).Shared or {}).Jobs or {})
    if jobs.unemployed then
        return {
            name = 'unemployed',
            label = jobs.unemployed.label or 'Civilian',
            payment = 10,
            type = jobs.unemployed.type or 'none',
            onduty = jobs.unemployed.defaultDuty or false,
            isboss = false,
            grade = { name = 'Freelancer', level = 0 }
        }
    end
    return { name = 'unemployed', label = 'Civilian', payment = 10, type = 'none', onduty = false, isboss = false, grade = { name = 'Freelancer', level = 0 } }
end

local function getDefaultGang()
    return { name = 'none', label = 'No Gang Affiliation', isboss = false, grade = { name = 'none', level = 0 } }
end

local function getDefaultMetadata()
    return { health = 600, hunger = 100, thirst = 100, cleanliness = 100, stress = 0, isdead = false, armor = 0, ishandcuffed = false, injail = 0, jailitems = {}, status = {}, rep = {}, callsign = 'NO CALLSIGN' }
end


local function normalizeGrade(grade)
    if type(grade) == 'table' then
        return {
            name = grade.name or 'No Grades',
            level = tonumber(grade.level or grade.grade or grade[1]) or 0,
            payment = tonumber(grade.payment) or 0,
            isboss = grade.isboss == true
        }
    end
    return { name = 'No Grades', level = tonumber(grade) or 0, payment = 0, isboss = false }
end

local function normalizeJob(job)
    if type(job) ~= 'table' then return getDefaultJob(getCore()) end
    if type(job.grade) ~= 'table' then job.grade = normalizeGrade(job.grade or 0) end
    job.name = tostring(job.name or 'unemployed'):lower()
    job.label = job.label or 'Civilian'
    job.payment = tonumber(job.payment or job.grade.payment) or 0
    job.type = job.type or 'none'
    job.onduty = job.onduty == true
    job.isboss = job.isboss == true or job.grade.isboss == true
    return job
end

local function normalizeGang(gang)
    if type(gang) ~= 'table' then return getDefaultGang() end
    if type(gang.grade) ~= 'table' then gang.grade = normalizeGrade(gang.grade or 0) end
    gang.name = tostring(gang.name or 'none'):lower()
    gang.label = gang.label or 'No Gang Affiliation'
    gang.isboss = gang.isboss == true or gang.grade.isboss == true
    return gang
end

local function generateCitizenId(core)
    if core and core.Player and core.Player.CreateCitizenId then
        local ok, citizenid = pcall(core.Player.CreateCitizenId)
        if ok and citizenid and citizenid ~= '' then return tostring(citizenid) end
    end
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local nums = '0123456789'
    for _ = 1, 25 do
        local id = ''
        for i = 1, 3 do
            local n = math.random(1, #chars)
            id = id .. chars:sub(n, n)
        end
        for i = 1, 5 do
            local n = math.random(1, #nums)
            id = id .. nums:sub(n, n)
        end
        local existing = safeDb(function()
            return MySQL.scalar.await('SELECT citizenid FROM players WHERE citizenid = ? LIMIT 1', { id })
        end, nil)
        if not existing then return id end
    end
    return ('N7%s%s'):format(os.time(), math.random(1000, 9999))
end

local function sanitizeText(value, maxLength, fallback)
    value = tostring(value or fallback or ''):gsub('[%c]', ''):match('^%s*(.-)%s*$') or ''
    if value == '' then value = tostring(fallback or '') end
    if #value > maxLength then value = value:sub(1, maxLength) end
    return value
end

local function normalizeGender(value)
    local raw = tostring(value or ''):lower():match('^%s*(.-)%s*$') or ''
    if raw == 'female' or raw == 'woman' or raw == 'f' or raw == '0' then return 0 end
    return 1 -- RSG format: 1 male, 0 female
end

local function genderName(value)
    return normalizeGender(value) == 0 and 'female' or 'male'
end

local function getLicense(src)
    local core = getCore()
    if core and core.Functions and core.Functions.GetIdentifier then
        local ok, license = pcall(core.Functions.GetIdentifier, src, 'license')
        if ok and license then return license end
    end
    return GetPlayerIdentifierByType(src, 'license') or GetPlayerIdentifier(src, 0)
end

local function compactCharacter(character)
    if type(character) ~= 'table' then return nil end
    character.charinfo = decodeJson(character.charinfo, {}) or {}
    character.money = decodeJson(character.money, {}) or {}
    character.job = normalizeJob(decodeJson(character.job, {}) or {})
    character.gang = normalizeGang(decodeJson(character.gang, {}) or {})
    character.metadata = decodeJson(character.metadata, {}) or {}
    character.position = decodeJson(character.position, character.position)
    character.cid = tonumber(character.cid or character.slot) or 1
    character.slot = tonumber(character.slot or character.cid) or character.cid
    if character.charinfo.gender ~= nil then
        character.charinfo.gender = normalizeGender(character.charinfo.gender)
    end
    return character
end

local function queryCharacters(src)
    local license = getLicense(src)
    if not license then return {}, 'missing_license' end

    local rows = safeDb(function()
        return MySQL.query.await('SELECT * FROM players WHERE license = ? ORDER BY COALESCE(slot, cid, 1), cid', { license })
    end, nil)

    if not rows then
        rows = safeDb(function()
            return MySQL.query.await('SELECT * FROM players WHERE license = ?', { license })
        end, {})
    end

    local characters = {}
    for _, row in ipairs(rows or {}) do
        characters[#characters + 1] = compactCharacter(row)
    end

    table.sort(characters, function(a, b)
        return (tonumber(a.slot or a.cid) or 1) < (tonumber(b.slot or b.cid) or 1)
    end)

    return characters
end

local function getCharacters(src)
    local chars, err = queryCharacters(src)
    if chars then return chars end

    local result, playersErr = callPlayers('GetCharacters', src)
    if result == false then return {}, tostring(playersErr or err or 'characters_failed') end

    local characters = {}
    if type(result) == 'table' then
        for _, character in ipairs(result) do
            characters[#characters + 1] = compactCharacter(character)
        end
    end
    return characters
end

local function sendCharacters(src, requestId)
    local characters, err = getCharacters(src)
    TriggerClientEvent('node7-charselect:client:characters', src, requestId, characters or {}, cfg().DefaultNumberOfCharacters or 4, err)
end

local function normalizeCharacterPayload(payload)
    payload = type(payload) == 'table' and payload or {}
    local charinfo = type(payload.charinfo) == 'table' and payload.charinfo or payload
    return {
        slot = tonumber(payload.slot or payload.cid) or nil,
        charinfo = {
            firstname = sanitizeText(charinfo.firstname or charinfo.firstName, 50, 'Unknown'),
            lastname = sanitizeText(charinfo.lastname or charinfo.lastName, 50, 'Unknown'),
            birthdate = sanitizeText(charinfo.birthdate or charinfo.dateOfBirth, 20, '1900-01-01'),
            gender = normalizeGender(charinfo.gender or charinfo.sex),
            nationality = sanitizeText(charinfo.nationality, 50, 'American'),
            backstory = sanitizeText(charinfo.backstory or '', 2000, '')
        }
    }
end

local function unloadCurrent(src, save)
    local core = getCore()
    if core and core.Functions and core.Functions.GetPlayer then
        local player = core.Functions.GetPlayer(src)
        if player and player.Functions then
            if save ~= false and core.Player and core.Player.Save then
                pcall(core.Player.Save, src)
            end
            if core.Player and core.Player.Logout then
                pcall(core.Player.Logout, src)
            elseif player.Functions.Logout then
                pcall(player.Functions.Logout)
            end
        end
    end

    if playersResourceReady() then
        local okLoaded, loaded = pcall(function() return exports['node7-players']:IsLoaded(src) end)
        if okLoaded and loaded then
            pcall(function() exports['node7-players']:UnloadPlayer(src, save ~= false) end)
        end
    end
end

local function createWithCore(src, data)
    local core = getCore()
    local license = getLicense(src)
    if not license then return nil, 'missing_license' end

    local existing = safeDb(function()
        return MySQL.scalar.await('SELECT citizenid FROM players WHERE license = ? AND COALESCE(slot, cid, 1) = ? LIMIT 1', { license, data.slot })
    end, nil)
    if existing then return nil, 'slot_taken' end

    local citizenid = generateCitizenId(core)
    local playerData = {
        citizenid = citizenid,
        cid = data.slot,
        slot = data.slot,
        license = license,
        name = GetPlayerName(src) or ('Player %s'):format(src),
        money = getDefaultMoney(core),
        charinfo = data.charinfo,
        job = getDefaultJob(core),
        gang = getDefaultGang(),
        position = cfg().DefaultSpawn or { x = -325.06, y = 773.62, z = 117.43, w = 286.0 },
        metadata = getDefaultMetadata(),
        weight = 35000,
        slots = 25
    }

    local inserted = safeDb(function()
        return MySQL.insert.await('INSERT INTO players (citizenid, cid, slot, license, name, money, charinfo, job, gang, position, metadata, weight, slots) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
            playerData.citizenid,
            playerData.cid,
            playerData.slot,
            playerData.license,
            playerData.name,
            encodeJson(playerData.money),
            encodeJson(playerData.charinfo),
            encodeJson(playerData.job),
            encodeJson(playerData.gang),
            encodeJson(playerData.position),
            encodeJson(playerData.metadata),
            playerData.weight,
            playerData.slots
        })
    end, false)

    if not inserted then
        local minimal = safeDb(function()
            return MySQL.insert.await('INSERT INTO players (citizenid, cid, slot, license, name, money, charinfo, job, gang, position, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
                playerData.citizenid,
                playerData.cid,
                playerData.slot,
                playerData.license,
                playerData.name,
                encodeJson(playerData.money),
                encodeJson(playerData.charinfo),
                encodeJson(playerData.job),
                encodeJson(playerData.gang),
                encodeJson(playerData.position),
                encodeJson(playerData.metadata)
            })
        end, false)
        if not minimal then return nil, 'db_insert_failed' end
    end

    return compactCharacter(playerData)
end

local function createCharacter(src, data)
    local core = getCore()
    if core then
        local created, err = createWithCore(src, data)
        if created then return created end
        return nil, err
    end

    local created, err = callPlayers('CreateCharacter', src, data)
    if created then return compactCharacter(created) end
    return nil, tostring(err or 'create_failed')
end

local function loadWithCore(src, citizenid)
    local core = getCore()
    local license = getLicense(src)
    if not license then return nil, 'missing_license' end

    unloadCurrent(src, true)

    local row = safeDb(function()
        return MySQL.single.await('SELECT * FROM players WHERE citizenid = ? LIMIT 1', { citizenid })
    end, nil)
    if not row then return nil, 'character_not_found' end
    if row.license and row.license ~= license then return nil, 'license_mismatch' end

    local playerData = compactCharacter(row)
    playerData.source = src
    playerData.license = license
    playerData.name = GetPlayerName(src) or playerData.name or ('Player %s'):format(src)

    if core and core.Player and core.Player.CheckPlayerData then
        local ok, playerObject = pcall(core.Player.CheckPlayerData, src, playerData)
        if ok then
            if playerObject and playerObject.PlayerData then
                return compactCharacter(playerObject.PlayerData)
            end

            if core.Functions and core.Functions.GetPlayer then
                local gotOk, loadedPlayer = pcall(core.Functions.GetPlayer, src)
                if gotOk and loadedPlayer and loadedPlayer.PlayerData then
                    return compactCharacter(loadedPlayer.PlayerData)
                end
            end

            return playerData
        end
        print(('^1[node7-charselect]^7 core player load failed, using safe player data: %s'):format(tostring(playerObject)))
    end

    return playerData
end

local function loadCharacter(src, citizenid)
    if getCore() then
        return loadWithCore(src, citizenid)
    end

    local player, err = callPlayers('LoadCharacter', src, citizenid)
    if player then return compactCharacter(player.PlayerData or player) end
    return nil, tostring(err or 'load_failed')
end

local function deleteWithCore(src, citizenid)
    local core = getCore()
    if not core or not core.Player or not core.Player.DeleteCharacter then return false, 'node7_core_player_api_missing' end
    local ok, err = pcall(core.Player.DeleteCharacter, src, citizenid)
    if not ok then return false, tostring(err) end
    return true
end

local function deleteCharacter(src, citizenid)
    if getCore() then return deleteWithCore(src, citizenid) end
    local success, err = callPlayers('DeleteCharacter', src, citizenid)
    if success then return true end
    return false, tostring(err or 'delete_failed')
end

local function eventError(src, requestId, eventName, err)
    local message = tostring(err or 'server_error')
    print(('^1[node7-charselect]^7 %s'):format(message))
    TriggerClientEvent(eventName, src, requestId or 0, false, message)
end

RegisterNetEvent('node7-charselect:server:beginSelection', function()
    local src = source
    local ok, err = pcall(function()
        unloadCurrent(src, true)
        sendCharacters(src, 0)
    end)
    if not ok then
        print(('^1[node7-charselect]^7 beginSelection failed: %s'):format(tostring(err)))
        TriggerClientEvent('node7-charselect:client:characters', src, 0, {}, cfg().DefaultNumberOfCharacters or 4, tostring(err))
    end
end)

RegisterNetEvent('node7-charselect:server:requestCharacters', function(requestId)
    local src = source
    local ok, err = pcall(function()
        sendCharacters(src, requestId)
    end)
    if not ok then
        print(('^1[node7-charselect]^7 requestCharacters failed: %s'):format(tostring(err)))
        TriggerClientEvent('node7-charselect:client:characters', src, requestId, {}, cfg().DefaultNumberOfCharacters or 4, tostring(err))
    end
end)


RegisterNetEvent('node7-charselect:server:createCharacter', function(requestId, payload)
    local src = source
    local ok, err = pcall(function()
        local data = normalizeCharacterPayload(payload)
        if not data.slot then
            TriggerClientEvent('node7-charselect:client:createResult', src, requestId, false, 'missing_slot')
            return
        end

        local created, createErr = createCharacter(src, data)
        if not created then
            TriggerClientEvent('node7-charselect:client:createResult', src, requestId, false, tostring(createErr or 'create_failed'))
            return
        end

        newlyCreatedBySource[src] = tostring(created.citizenid or '')
        TriggerClientEvent('node7-charselect:client:createResult', src, requestId, true, compactCharacter(created))
        sendCharacters(src, 0)
    end)
    if not ok then eventError(src, requestId, 'node7-charselect:client:createResult', err) end
end)

RegisterNetEvent('node7-charselect:server:selectCharacter', function(requestId, citizenid)
    local src = source
    local ok, err = pcall(function()
        citizenid = tostring(citizenid or '')
        if citizenid == '' then
            TriggerClientEvent('node7-charselect:client:selectResult', src, requestId, false, 'missing_citizenid')
            return
        end

        local data, loadErr = loadCharacter(src, citizenid)
        if not data then
            TriggerClientEvent('node7-charselect:client:selectResult', src, requestId, false, tostring(loadErr or 'load_failed'))
            return
        end

        local created = newlyCreatedBySource[src] == citizenid
        newlyCreatedBySource[src] = nil

        debugPrint(('Loaded %s for %s'):format(tostring(data.citizenid), tostring(src)))
        TriggerClientEvent('node7-charselect:client:selectResult', src, requestId, true, data, created)
    end)
    if not ok then eventError(src, requestId, 'node7-charselect:client:selectResult', err) end
end)

RegisterNetEvent('node7-charselect:server:deleteCharacter', function(requestId, citizenid)
    local src = source
    local ok, err = pcall(function()
        citizenid = tostring(citizenid or '')
        if citizenid == '' then
            TriggerClientEvent('node7-charselect:client:deleteResult', src, requestId, false, 'missing_citizenid')
            return
        end

        local success, deleteErr = deleteCharacter(src, citizenid)
        if not success then
            TriggerClientEvent('node7-charselect:client:deleteResult', src, requestId, false, tostring(deleteErr or 'delete_failed'))
            return
        end

        TriggerClientEvent('node7-charselect:client:deleteResult', src, requestId, true)
        sendCharacters(src, 0)
    end)
    if not ok then eventError(src, requestId, 'node7-charselect:client:deleteResult', err) end
end)

RegisterNetEvent('node7-charselect:server:savePosition', function(position)
    local src = source
    if type(position) ~= 'table' then return end

    pcall(function()
        local core = getCore()
        if core and core.Functions and core.Functions.GetPlayer then
            local player = core.Functions.GetPlayer(src)
            if player and player.Functions and player.Functions.SetPlayerData then
                player.Functions.SetPlayerData('position', {
                    x = tonumber(position.x),
                    y = tonumber(position.y),
                    z = tonumber(position.z),
                    w = tonumber(position.w)
                })
                if core.Player and core.Player.Save then pcall(core.Player.Save, src) end
                return
            end
        end

        callPlayers('SetPosition', src, {
            x = tonumber(position.x),
            y = tonumber(position.y),
            z = tonumber(position.z),
            w = tonumber(position.w)
        })
    end)
end)

RegisterNetEvent('node7-charselect:server:logout', function()
    local src = source
    newlyCreatedBySource[src] = nil
    pcall(unloadCurrent, src, true)
    TriggerClientEvent('node7-charselect:client:chooseChar', src)
end)

RegisterNetEvent('node7-charselect:server:disconnect', function()
    newlyCreatedBySource[source] = nil
    DropPlayer(source, 'Disconnected from NODE7')
end)

AddEventHandler('playerDropped', function()
    newlyCreatedBySource[source] = nil
end)

RegisterCommand('logout', function(source)
    if source <= 0 then return end
    unloadCurrent(source, true)
    TriggerClientEvent('node7-charselect:client:chooseChar', source)
end, false)

RegisterCommand('charselect', function(source)
    if source <= 0 then return end
    unloadCurrent(source, true)
    TriggerClientEvent('node7-charselect:client:chooseChar', source)
end, false)

RegisterCommand('characters', function(source)
    if source <= 0 then return end
    unloadCurrent(source, true)
    TriggerClientEvent('node7-charselect:client:chooseChar', source)
end, false)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= RESOURCE then return end
    print('^2[node7-charselect]^7 Started | NODE7 core players | last-location only | core grade fix | no ped preview')
end)

exports('OpenCharacterSelect', function(source)
    source = tonumber(source)
    if not source or source <= 0 then return false end
    unloadCurrent(source, true)
    TriggerClientEvent('node7-charselect:client:chooseChar', source)
    return true
end)
