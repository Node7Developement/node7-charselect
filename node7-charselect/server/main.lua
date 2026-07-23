local RESOURCE = GetCurrentResourceName()
local LoadingLocks = {}

local Config = Node7CharSelectConfig or {}

local function debugPrint(message)
    if Config.Debug then
        print(('^3[node7-charselect]^7 %s'):format(tostring(message)))
    end
end

local function trim(value)
    if value == nil then return nil end
    return tostring(value):gsub('[%c]', ''):match('^%s*(.-)%s*$')
end

local function cleanText(value, minLength, maxLength, allowEmpty)
    value = trim(value)
    if value == nil then return allowEmpty and '' or nil end
    if value == '' and allowEmpty then return '' end
    if value == '' then return nil end
    if minLength and #value < minLength then return nil end
    if maxLength and #value > maxLength then return nil end
    return value
end

local function formatError(error)
    error = tostring(error or 'unknown_error')
    return error:gsub('_', ' ')
end

local function isUnknown(value)
    value = tostring(value or ''):lower():match('^%s*(.-)%s*$')
    return value == '' or value == 'unknown' or value == 'n/a' or value == 'none'
end

local function isBadPosition(position)
    if type(position) ~= 'table' then return true end
    local x, y, z = tonumber(position.x), tonumber(position.y), tonumber(position.z)
    if not x or not y or not z then return true end
    if math.abs(x) < 0.01 and math.abs(y) < 0.01 and math.abs(z) < 0.01 then return true end
    if z < -50.0 then return true end

    for _, bad in ipairs(Config.BadPositions or {}) do
        local bx, by, bz = tonumber(bad.x), tonumber(bad.y), tonumber(bad.z)
        local radius = tonumber(bad.radius) or 0.0
        if bx and by and bz and radius > 0.0 then
            local dx, dy, dz = x - bx, y - by, z - bz
            if ((dx * dx) + (dy * dy) + (dz * dz)) <= (radius * radius) then
                return true
            end
        end
    end

    return false
end

local function normalizedPosition(position, fallbackAllowed)
    local fallback = Config.FirstSpawnPosition or { x = -277.76, y = 806.73, z = 119.38, w = 275.0 }
    if fallbackAllowed ~= false and Config.BadPositionFallback ~= false and isBadPosition(position) then
        return {
            x = tonumber(fallback.x) or -277.76,
            y = tonumber(fallback.y) or 806.73,
            z = tonumber(fallback.z) or 119.38,
            w = tonumber(fallback.w or fallback.h or fallback.heading) or 275.0,
            fallback = true,
            fallbackReason = Config.BadPositionFallbackMessage or 'Saved location was invalid.'
        }
    end

    position = type(position) == 'table' and position or fallback
    return {
        x = tonumber(position.x) or tonumber(fallback.x) or -277.76,
        y = tonumber(position.y) or tonumber(fallback.y) or 806.73,
        z = tonumber(position.z) or tonumber(fallback.z) or 119.38,
        w = tonumber(position.w or position.h or position.heading) or tonumber(fallback.w or fallback.h or fallback.heading) or 275.0,
        fallback = false
    }
end

local function isValidSource(source)
    source = tonumber(source)
    return source and source > 0 and GetPlayerName(source) ~= nil
end

local function safeCallExport(name, ...)
    if GetResourceState('node7-players') ~= 'started' then
        return false, 'node7_players_not_started'
    end

    local exportTable = exports['node7-players']
    local fn = exportTable and exportTable[name]
    if not fn then
        return false, ('missing_export_%s'):format(name)
    end

    local args = { ... }

    local ok, result, extra = pcall(function()
        return fn(table.unpack(args))
    end)

    if ok and result ~= false then
        return true, result, extra
    end

    local firstError = ok and extra or result

    -- Some CFX export proxy builds behave better with method-style calls.
    -- Try that as a fallback without exposing any new SQL/database path.
    local ok2, result2, extra2 = pcall(function()
        return fn(exportTable, table.unpack(args))
    end)

    if ok2 and result2 ~= false then
        return true, result2, extra2
    end

    local errorText = extra2 or firstError or result2 or 'players_export_failed'
    if not ok and not ok2 then
        print(('^1[node7-charselect]^7 node7-players export %s failed: %s / %s'):format(name, tostring(result), tostring(result2)))
        return false, 'players_export_failed'
    end

    return false, errorText
end

local function validateCharInfo(payload)
    payload = type(payload) == 'table' and payload or {}
    local rules = Config.RequiredFields or {}

    local firstname = cleanText(payload.firstname, rules.firstname and rules.firstname.min or 2, rules.firstname and rules.firstname.max or 50, false)
    if not firstname or isUnknown(firstname) then return nil, 'invalid_firstname' end

    local lastname = cleanText(payload.lastname, rules.lastname and rules.lastname.min or 2, rules.lastname and rules.lastname.max or 50, false)
    if not lastname or isUnknown(lastname) then return nil, 'invalid_lastname' end

    local birthdate = cleanText(payload.birthdate, rules.birthdate and rules.birthdate.min or 6, rules.birthdate and rules.birthdate.max or 20, false)
    if not birthdate or isUnknown(birthdate) then return nil, 'invalid_birthdate' end

    local gender = cleanText(payload.gender, rules.gender and rules.gender.min or 1, rules.gender and rules.gender.max or 20, false)
    if not gender or isUnknown(gender) then return nil, 'invalid_gender' end

    local nationality = cleanText(payload.nationality, rules.nationality and rules.nationality.min or 2, rules.nationality and rules.nationality.max or 50, false)
    if not nationality or isUnknown(nationality) then return nil, 'invalid_nationality' end

    local backstory = cleanText(payload.backstory or '', rules.backstory and rules.backstory.min or 0, rules.backstory and rules.backstory.max or 500, true) or ''

    return {
        firstname = firstname,
        lastname = lastname,
        birthdate = birthdate,
        gender = gender,
        nationality = nationality,
        backstory = backstory
    }
end

local function summarizeCharacter(character)
    character = type(character) == 'table' and character or {}
    local charinfo = type(character.charinfo) == 'table' and character.charinfo or {}
    local job = type(character.job) == 'table' and character.job or {}
    local money = type(character.money) == 'table' and character.money or {}
    local position = type(character.position) == 'table' and character.position or nil
    local firstname = trim(charinfo.firstname or charinfo.firstName) or 'Unknown'
    local lastname = trim(charinfo.lastname or charinfo.lastName) or 'Unknown'
    local requiresSetup = isUnknown(firstname) or isUnknown(lastname)

    return {
        citizenid = character.citizenid,
        slot = tonumber(character.slot or character.cid) or 1,
        cid = tonumber(character.slot or character.cid) or 1,
        name = requiresSetup and 'Finish Character Setup' or (('%s %s'):format(firstname, lastname)),
        firstname = firstname,
        lastname = lastname,
        birthdate = charinfo.birthdate or charinfo.dateOfBirth or 'Unknown',
        gender = charinfo.gender or charinfo.sex or 'Unknown',
        nationality = charinfo.nationality or 'Unknown',
        job = job.name or 'unemployed',
        grade = job.grade or 0,
        cash = money.cash or 0,
        bank = money.bank or 0,
        gold = money.gold or 0,
        last_played = character.last_played,
        created_at = character.created_at,
        requires_setup = requiresSetup,
        has_position = position ~= nil and not isBadPosition(position)
    }
end

local function buildSlots(characters)
    local maxCharacters = tonumber(Config.MaxCharacters) or 4
    local bySlot = {}

    for _, character in ipairs(characters or {}) do
        local summary = summarizeCharacter(character)
        bySlot[summary.slot] = summary
    end

    local slots = {}
    for slot = 1, maxCharacters do
        if bySlot[slot] then
            slots[#slots + 1] = {
                slot = slot,
                empty = false,
                character = bySlot[slot]
            }
        else
            slots[#slots + 1] = {
                slot = slot,
                empty = true,
                character = nil
            }
        end
    end

    return slots
end

local function playerPayload(playerObject, positionOverride)
    local playerData = type(playerObject) == 'table' and (playerObject.PlayerData or playerObject) or {}
    local position = positionOverride or normalizedPosition(playerData.position, true)
    local charinfo = type(playerData.charinfo) == 'table' and playerData.charinfo or {}

    return {
        citizenid = playerData.citizenid,
        slot = playerData.slot or playerData.cid,
        name = playerData.name or ((tostring(charinfo.firstname or 'Unknown') .. ' ' .. tostring(charinfo.lastname or 'Unknown'))),
        charinfo = charinfo,
        position = position
    }
end


local RequestHandlers = {}

RequestHandlers.getCharacters = function(source, _payload)
    if not isValidSource(source) then
        return { ok = false, error = 'invalid source' }
    end

    local ok, charactersOrErr = safeCallExport('GetCharacters', source)
    if not ok then
        return { ok = false, error = formatError(charactersOrErr) }
    end

    return {
        ok = true,
        slots = buildSlots(charactersOrErr or {}),
        maxCharacters = tonumber(Config.MaxCharacters) or 4,
        labels = Config.DefaultLabels or {},
        allowDelete = Config.AllowDelete == true
    }
end

RequestHandlers.playCharacter = function(source, payload)
    if not isValidSource(source) then
        return { ok = false, error = 'invalid source' }
    end
    if LoadingLocks[source] then return { ok = false, error = 'load in progress' } end
    LoadingLocks[source] = true

    payload = type(payload) == 'table' and payload or {}
    local citizenid = trim(payload.citizenid)
    if not citizenid then
        LoadingLocks[source] = nil
        return { ok = false, error = 'missing citizenid' }
    end

    local ok, playerOrErr = safeCallExport('LoadCharacter', source, citizenid)
    LoadingLocks[source] = nil

    if not ok then return { ok = false, error = formatError(playerOrErr) } end

    local player = playerPayload(playerOrErr)
    if player.position and player.position.fallback then
        safeCallExport('SetPosition', source, player.position)
    end
    debugPrint(('Loaded %s at last location for source %s'):format(tostring(player.citizenid), source))
    return { ok = true, player = player, position = player.position }
end

RequestHandlers.createCharacter = function(source, payload)
    if not isValidSource(source) then
        return { ok = false, error = 'invalid source' }
    end
    if LoadingLocks[source] then return { ok = false, error = 'load in progress' } end
    LoadingLocks[source] = true

    payload = type(payload) == 'table' and payload or {}
    local charinfo, validationError = validateCharInfo(payload.charinfo or payload)
    if not charinfo then
        LoadingLocks[source] = nil
        return { ok = false, error = formatError(validationError) }
    end

    local slot = tonumber(payload.slot)
    if not slot or slot < 1 or slot > (tonumber(Config.MaxCharacters) or 4) then
        LoadingLocks[source] = nil
        return { ok = false, error = 'invalid slot' }
    end

    local ok, characterOrErr = safeCallExport('CreateCharacter', source, {
        slot = slot,
        charinfo = charinfo
    })
    if not ok then
        LoadingLocks[source] = nil
        return { ok = false, error = formatError(characterOrErr) }
    end

    local citizenid = characterOrErr and characterOrErr.citizenid
    if not citizenid then
        LoadingLocks[source] = nil
        return { ok = false, error = 'created character missing citizenid' }
    end

    local loadedOk, playerOrErr = safeCallExport('LoadCharacter', source, citizenid)
    if not loadedOk then
        LoadingLocks[source] = nil
        return { ok = false, error = formatError(playerOrErr) }
    end

    local firstSpawn = normalizedPosition(Config.FirstSpawnPosition, false)
    safeCallExport('SetPosition', source, firstSpawn)

    LoadingLocks[source] = nil

    local player = playerPayload(playerOrErr, firstSpawn)
    debugPrint(('Created and loaded %s slot %s for source %s'):format(tostring(player.citizenid), tostring(slot), source))
    return { ok = true, player = player, position = firstSpawn, created = true }
end

RequestHandlers.finishSetup = function(source, payload)
    if not isValidSource(source) then
        return { ok = false, error = 'invalid source' }
    end
    if LoadingLocks[source] then return { ok = false, error = 'load in progress' } end
    LoadingLocks[source] = true

    payload = type(payload) == 'table' and payload or {}
    local citizenid = trim(payload.citizenid)
    if not citizenid then
        LoadingLocks[source] = nil
        return { ok = false, error = 'missing citizenid' }
    end

    local charinfo, validationError = validateCharInfo(payload.charinfo or payload)
    if not charinfo then
        LoadingLocks[source] = nil
        return { ok = false, error = formatError(validationError) }
    end

    local loadedOk, playerOrErr = safeCallExport('LoadCharacter', source, citizenid)
    if not loadedOk then
        LoadingLocks[source] = nil
        return { ok = false, error = formatError(playerOrErr) }
    end

    local setOk, setErr = safeCallExport('SetCharInfo', source, charinfo)
    if not setOk then
        LoadingLocks[source] = nil
        return { ok = false, error = formatError(setErr) }
    end

    local firstSpawn = normalizedPosition(Config.FirstSpawnPosition, false)
    safeCallExport('SetPosition', source, firstSpawn)

    LoadingLocks[source] = nil

    local player = playerPayload(playerOrErr, firstSpawn)
    player.name = ('%s %s'):format(charinfo.firstname, charinfo.lastname)
    player.charinfo = charinfo
    debugPrint(('Finished setup for %s source %s'):format(tostring(citizenid), source))
    return { ok = true, player = player, position = firstSpawn, setup = true }
end

RequestHandlers.logout = function(source, payload)
    if not isValidSource(source) then
        return { ok = false, error = 'invalid source' }
    end

    payload = type(payload) == 'table' and payload or {}
    local position = normalizedPosition(payload.position, false)

    local setOk, setErr = safeCallExport('SetPosition', source, position)
    if not setOk then
        if tostring(setErr) == 'player_not_loaded' then
            return { ok = true, alreadyUnloaded = true }
        end
        return { ok = false, error = formatError(setErr) }
    end

    local saveOk, saveErr = safeCallExport('SavePlayer', source)
    if not saveOk then
        return { ok = false, error = formatError(saveErr) }
    end

    local unloadOk, unloadErr = safeCallExport('UnloadPlayer', source, true)
    if not unloadOk and tostring(unloadErr) ~= 'player_not_loaded' then
        return { ok = false, error = formatError(unloadErr) }
    end

    return { ok = true }
end

RequestHandlers.deleteCharacter = function(source, payload)
    if not isValidSource(source) then
        return { ok = false, error = 'invalid source' }
    end
    if Config.AllowDelete ~= true then return { ok = false, error = 'delete disabled' } end

    payload = type(payload) == 'table' and payload or {}
    local citizenid = trim(payload.citizenid)
    if not citizenid then return { ok = false, error = 'missing citizenid' } end

    local ok, result = safeCallExport('DeleteCharacter', source, citizenid)
    if not ok then return { ok = false, error = formatError(result) } end

    return { ok = true }
end

local function handleCharselectRequest(source, requestId, action, payload)
    local handler = RequestHandlers[tostring(action or '')]
    local result

    if not handler then
        result = { ok = false, error = 'unknown request' }
    else
        local ok, response = pcall(handler, source, payload)
        if ok then
            result = response
        else
            print(('^1[node7-charselect]^7 request %s failed for source %s: %s'):format(tostring(action), tostring(source), tostring(response)))
            result = { ok = false, error = 'server request failed' }
        end
    end

    TriggerClientEvent('node7-charselect:client:response', source, requestId, result)
end

RegisterNetEvent('node7-charselect:server:request', function(requestId, action, payload)
    handleCharselectRequest(source, requestId, action, payload)
end)

-- Compatibility for old event name during migration.
RegisterNetEvent('node7-multicharacter:server:request', function(requestId, action, payload)
    handleCharselectRequest(source, requestId, action, payload)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= RESOURCE then return end
    print('^2[node7-charselect]^7 started | fullscreen NUI | server-event source routing | no SQL')
end)
