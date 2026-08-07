local Node7Core = exports['node7-core']:GetCoreObject()
local RestoreLocks = {}
local PendingUnloads = {}
local LoadLocks = {}

local function debugPrint(message)
    if Config.Debug then
        print(('[node7-wagon-carcasses] %s'):format(tostring(message)))
    end
end

local function notify(source, message, kind)
    Node7Core.Functions.Notify(source, {
        title = 'Wagon Carcasses',
        description = tostring(message),
        type = kind or 'info',
        duration = 5000,
    })
end

local function getPlayer(source)
    local player = Node7Core.Functions.GetPlayer(tonumber(source))
    if not player or not player.PlayerData or not player.PlayerData.citizenid then return nil end
    return player
end

local function citizenId(source)
    local player = getPlayer(source)
    return player and tostring(player.PlayerData.citizenid) or nil
end

local function getEntity(networkId)
    networkId = tonumber(networkId) or 0
    if networkId <= 0 then return nil end

    local ok, entity = pcall(NetworkGetEntityFromNetworkId, networkId)
    if not ok or not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    return entity
end

local function playerNearEntity(source, entity, maximumDistance)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not entity or entity == 0 then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(entity)) <= (tonumber(maximumDistance) or 7.0)
end

local function entitiesNear(a, b, maximumDistance)
    if not a or not b then return false end
    return #(GetEntityCoords(a) - GetEntityCoords(b)) <= (tonumber(maximumDistance) or 7.0)
end

local function hasSharedKey(keys, id)
    for _, value in ipairs(Node7Carcasses.SafeDecode(keys)) do
        if tostring(value) == tostring(id) then return true end
    end
    return false
end

local function getWagon(wagonid)
    return MySQL.single.await([[
        SELECT `wagonid`, `citizenid`, `model`, `name`, `network_id`, `locked`, `keys`
        FROM `node7_wagons`
        WHERE `wagonid` = ?
        LIMIT 1
    ]], { tostring(wagonid or '') })
end

local function isLocked(value)
    if value == true then return true end
    if value == false or value == nil then return false end
    if tonumber(value) ~= nil then return tonumber(value) == 1 end

    value = tostring(value):lower()
    return value == 'true' or value == 'locked' or value == 'yes' or value == '1'
end

local function hashEquals(a, b)
    a, b = tonumber(a), tonumber(b)
    if not a or not b then return false end
    if a == b then return true end
    return (a & 0xFFFFFFFF) == (b & 0xFFFFFFFF)
end

local function wagonModelHash(model)
    local numeric = tonumber(model)
    if numeric then return numeric end
    if model == nil or tostring(model) == '' then return nil end
    return joaat(tostring(model))
end

local function canAccessWagon(source, wagon)
    local id = citizenId(source)
    if not id or not wagon then return false, 'player_missing' end

    -- Locked means nobody opens carcass storage, including the owner.
    if isLocked(wagon.locked) then return false, 'wagon_locked' end
    if tostring(wagon.citizenid) == id then return true end
    if hasSharedKey(wagon.keys, id) then return true end

    return false, 'no_access'
end

local function validateWagonAccess(source, wagonid, networkId)
    local wagon = getWagon(wagonid)
    if not wagon then return nil, nil, 'wagon_missing' end

    networkId = tonumber(networkId) or 0
    local entity = getEntity(networkId)
    if not entity then return nil, nil, 'wagon_entity_missing' end
    if not playerNearEntity(source, entity, (Config.Interaction or {}).serverDistance) then
        return nil, nil, 'too_far'
    end

    local stateOk, state = pcall(function() return Entity(entity).state end)
    if stateOk and state and state.node7WagonId and tostring(state.node7WagonId) ~= tostring(wagonid) then
        return nil, nil, 'wagon_state_mismatch'
    end

    local expectedModel = wagonModelHash(wagon.model)
    if expectedModel and not hashEquals(GetEntityModel(entity), expectedModel) then
        return nil, nil, 'wagon_model_mismatch'
    end

    local allowed, reason = canAccessWagon(source, wagon)
    if not allowed then return nil, nil, reason end

    return wagon, entity
end

local function isDeadEntity(entity)
    if not entity or entity == 0 then return false end

    if type(IsPedDeadOrDying) == 'function' then
        local ok, dead = pcall(IsPedDeadOrDying, entity, true)
        if ok and dead == true then return true end
    end

    if type(IsPedFatallyInjured) == 'function' then
        local ok, dead = pcall(IsPedFatallyInjured, entity)
        if ok and dead == true then return true end
    end

    if type(IsEntityDead) == 'function' then
        local ok, dead = pcall(IsEntityDead, entity)
        if ok and dead == true then return true end
    end

    if type(GetEntityHealth) == 'function' then
        local ok, health = pcall(GetEntityHealth, entity)
        if ok and tonumber(health) and tonumber(health) <= 0 then return true end
    end

    return false
end

local function validateCarcassEntity(networkId, expectedModel, source, allowCarried)
    local entity = getEntity(networkId)
    if not entity then return nil, 'carcass_entity_missing' end

    local entityType = 0
    if type(GetEntityType) == 'function' then
        local ok, value = pcall(GetEntityType, entity)
        if ok then entityType = tonumber(value) or 0 end
    end

    if entityType ~= 1 then return nil, 'carcass_not_ped' end

    local model = GetEntityModel(entity)
    if not Node7Carcasses.HashEquals(model, expectedModel) then return nil, 'carcass_model_mismatch' end
    if not Node7Carcasses.IsAnimalModel(model) then return nil, 'animal_blacklisted' end

    if not isDeadEntity(entity) then
        -- Rockstar's active shoulder-carry state can briefly report a living
        -- health state to the server even though the client owns a dead animal
        -- carcass. Only permit that narrow case when the requesting player and
        -- the exact whitelisted animal network entity are physically together.
        local carriedPhysicalMatch = allowCarried == true
            and source ~= nil
            and playerNearEntity(source, entity, 2.75)

        if not carriedPhysicalMatch then return nil, 'animal_not_dead' end
    end

    return entity
end

local function sanitizeMetaTags(value)
    if type(value) ~= 'table' then return {} end
    local clean = {}
    for index = 1, math.min(#value, 96) do
        local item = value[index]
        if type(item) == 'table' then
            clean[#clean + 1] = {
                drawable = tonumber(item.drawable) or 0,
                albedo = tonumber(item.albedo) or 0,
                normal = tonumber(item.normal) or 0,
                material = tonumber(item.material) or 0,
                palette = tonumber(item.palette) or 0,
                tint0 = tonumber(item.tint0) or 0,
                tint1 = tonumber(item.tint1) or 0,
                tint2 = tonumber(item.tint2) or 0,
            }
        end
    end
    return clean
end

local function ensureColumn(name, definition)
    local exists = MySQL.scalar.await([[
        SELECT COUNT(*)
        FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'node7_wagon_carcasses'
          AND COLUMN_NAME = ?
    ]], { name })
    if tonumber(exists) == 0 then
        MySQL.query.await(('ALTER TABLE `node7_wagon_carcasses` ADD COLUMN `%s` %s'):format(name, definition))
    end
end

local function createSchema()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `node7_wagon_carcasses` (
            `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
            `wagonid` VARCHAR(16) NOT NULL,
            `owner_citizenid` VARCHAR(50) NOT NULL,
            `loaded_by` VARCHAR(50) NOT NULL,
            `animal_model` BIGINT NOT NULL,
            `animal_model_name` VARCHAR(64) NOT NULL,
            `label` VARCHAR(64) NOT NULL,
            `group_name` VARCHAR(32) NOT NULL,
            `is_skinned` TINYINT(1) NOT NULL DEFAULT 1,
            `meta_outfit_hash` BIGINT NOT NULL DEFAULT 0,
            `meta_tags` LONGTEXT NULL,
            `damage_cleanliness` INT NOT NULL DEFAULT 0,
            `quality` INT NOT NULL DEFAULT 0,
            `slot` INT UNSIGNED NOT NULL,
            `live_net_id` INT UNSIGNED NOT NULL DEFAULT 0,
            `status` VARCHAR(20) NOT NULL DEFAULT 'loaded',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `node7_wagon_carcasses_slot_unique` (`wagonid`, `slot`),
            KEY `node7_wagon_carcasses_wagon_index` (`wagonid`),
            KEY `node7_wagon_carcasses_live_index` (`live_net_id`),
            CONSTRAINT `node7_wagon_carcasses_wagon_fk`
                FOREIGN KEY (`wagonid`) REFERENCES `node7_wagons` (`wagonid`)
                ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])

    ensureColumn('is_skinned', 'TINYINT(1) NOT NULL DEFAULT 1 AFTER `group_name`')
    ensureColumn('meta_outfit_hash', 'BIGINT NOT NULL DEFAULT 0 AFTER `is_skinned`')
    ensureColumn('meta_tags', 'LONGTEXT NULL AFTER `meta_outfit_hash`')
    ensureColumn('damage_cleanliness', 'INT NOT NULL DEFAULT 0 AFTER `meta_tags`')
    ensureColumn('quality', 'INT NOT NULL DEFAULT 0 AFTER `damage_cleanliness`')

    -- Records created before v2.1.0 did not preserve processing state. Treat
    -- them as already skinned so legacy data can never produce fresh rewards.
    MySQL.update.await('UPDATE `node7_wagon_carcasses` SET `is_skinned` = 1 WHERE `is_skinned` <> 1 OR `is_skinned` IS NULL')
end

local function findFreeSlot(wagonid)
    local rows = MySQL.query.await(
        'SELECT `slot` FROM `node7_wagon_carcasses` WHERE `wagonid` = ? ORDER BY `slot` ASC',
        { wagonid }
    ) or {}

    local used = {}
    for _, row in ipairs(rows) do
        local slot = tonumber(row.slot)
        if slot and slot > 0 then used[slot] = true end
    end

    local slot = 1
    while used[slot] do slot = slot + 1 end
    return slot
end

local function acquireLoadLock(wagonid)
    while LoadLocks[wagonid] do Wait(0) end
    LoadLocks[wagonid] = true
end

local function releaseLoadLock(wagonid)
    LoadLocks[wagonid] = nil
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(250) end
    createSchema()

    -- Network IDs never survive a resource or full server restart. Stored
    -- records remain valid, but no physical hidden entity is restored.
    MySQL.update.await('UPDATE `node7_wagon_carcasses` SET `live_net_id` = 0')

    local loadTimeout = math.max(30, math.floor(tonumber(Config.PendingLoadTimeoutSeconds) or 90))
    local unloadTimeout = math.max(30, math.floor(tonumber(Config.PendingUnloadTimeoutSeconds) or 45))

    MySQL.update.await(([[
        DELETE FROM `node7_wagon_carcasses`
        WHERE `status` = 'pending_load'
          AND `updated_at` < (CURRENT_TIMESTAMP - INTERVAL %d SECOND)
    ]]):format(loadTimeout))

    MySQL.update.await(([[
        UPDATE `node7_wagon_carcasses`
        SET `status` = 'loaded'
        WHERE `status` = 'pending_unload'
          AND `updated_at` < (CURRENT_TIMESTAMP - INTERVAL %d SECOND)
    ]]):format(unloadTimeout))

    print(('[node7-wagon-carcasses] Database ready. v%s'):format(Config.Version))
end)

CreateThread(function()
    while true do
        Wait(60000)

        local loadTimeout = math.max(30, math.floor(tonumber(Config.PendingLoadTimeoutSeconds) or 90))
        local unloadTimeout = math.max(30, math.floor(tonumber(Config.PendingUnloadTimeoutSeconds) or 45))

        MySQL.update.await(([[
            DELETE FROM `node7_wagon_carcasses`
            WHERE `status` = 'pending_load'
              AND `updated_at` < (CURRENT_TIMESTAMP - INTERVAL %d SECOND)
        ]]):format(loadTimeout))

        MySQL.update.await(([[
            UPDATE `node7_wagon_carcasses`
            SET `status` = 'loaded'
            WHERE `status` = 'pending_unload'
              AND `updated_at` < (CURRENT_TIMESTAMP - INTERVAL %d SECOND)
        ]]):format(unloadTimeout))

        local now = os.time()
        for recordId, pending in pairs(PendingUnloads) do
            if not pending or pending.expires < now then
                PendingUnloads[recordId] = nil
            end
        end
    end
end)

RegisterNetEvent('node7-wagon-carcasses:server:reserveLoad', function(payload)
    local source = source
    payload = type(payload) == 'table' and payload or {}

    local wagonid = tostring(payload.wagonid or '')
    local wagonNetId = tonumber(payload.wagonNetId) or 0
    local carcassNetId = tonumber(payload.carcassNetId) or 0
    local animalModel = tonumber(payload.animalModel) or 0
    local wasCarried = payload.wasCarried == true
    local isSkinned = payload.isSkinned == true
    local metaOutfitHash = tonumber(payload.metaOutfitHash) or 0
    local metaTags = sanitizeMetaTags(payload.metaTags)
    local damageCleanliness = tonumber(payload.damageCleanliness) or 0
    local quality = tonumber(payload.quality) or 0
    if wagonid == '' or wagonNetId == 0 or carcassNetId == 0 or animalModel == 0 then return end

    if Config.RequireSkinnedCarcass ~= false and not isSkinned then
        notify(source, 'Skin the animal first. Only carcasses already processed by your hunting system can be stored.', 'error')
        return
    end

    local wagon, wagonEntity, reason = validateWagonAccess(source, wagonid, wagonNetId)
    if not wagon then
        notify(source, reason == 'wagon_locked' and 'This wagon is locked.' or 'You cannot use this wagon.', 'error')
        return
    end

    local carcass, carcassReason = validateCarcassEntity(carcassNetId, animalModel, source, wasCarried)
    if not carcass then
        notify(source, ('Carcass rejected: %s.'):format(carcassReason), 'error')
        return
    end

    if Config.RequireSkinnedCarcass ~= false then
        local processed = false
        for _ = 1, 10 do
            local stateOk, carcassState = pcall(function() return Entity(carcass).state end)
            if stateOk and carcassState and carcassState.node7WagonCarcassProcessed == true then
                processed = true
                break
            end
            Wait(75)
        end
        if not processed then
            notify(source, 'The processed carcass state could not be verified. Pick it up and try again.', 'error')
            return
        end
    end

    if not playerNearEntity(source, carcass, 4.0) or not entitiesNear(wagonEntity, carcass, 8.0) then
        notify(source, 'Carry the carcass to the rear of the wagon.', 'error')
        return
    end

    local duplicate = MySQL.scalar.await(
        'SELECT `id` FROM `node7_wagon_carcasses` WHERE `live_net_id` = ? LIMIT 1',
        { carcassNetId }
    )
    if duplicate then
        notify(source, 'That carcass is already stored.', 'error')
        return
    end

    local profile = Node7Carcasses.GetAnimalProfile(animalModel)
    if not profile then
        notify(source, 'That animal is blacklisted from carcass storage.', 'error')
        return
    end

    local loader = citizenId(source)
    acquireLoadLock(wagonid)

    local slot = findFreeSlot(wagonid)
    local recordId
    local insertOk, insertResult = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO `node7_wagon_carcasses`
                (`wagonid`, `owner_citizenid`, `loaded_by`, `animal_model`, `animal_model_name`,
                 `label`, `group_name`, `is_skinned`, `meta_outfit_hash`, `meta_tags`,
                 `damage_cleanliness`, `quality`, `slot`, `live_net_id`, `status`)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending_load')
        ]], {
            wagonid,
            tostring(wagon.citizenid),
            loader,
            animalModel,
            profile.modelName,
            profile.label,
            profile.group,
            isSkinned and 1 or 0,
            metaOutfitHash,
            json.encode(metaTags),
            damageCleanliness,
            quality,
            slot,
            carcassNetId,
        })
    end)
    if insertOk then recordId = insertResult end

    releaseLoadLock(wagonid)

    if not recordId then
        notify(source, 'The carcass storage record could not be reserved.', 'error')
        return
    end

    TriggerClientEvent('node7-wagon-carcasses:client:attachReserved', source, {
        id = recordId,
        wagonid = wagonid,
        wagonNetId = wagonNetId,
        carcassNetId = carcassNetId,
        model = animalModel,
        label = profile.label,
        group_name = profile.group,
        is_skinned = isSkinned and 1 or 0,
        meta_outfit_hash = metaOutfitHash,
        meta_tags = json.encode(metaTags),
        damage_cleanliness = damageCleanliness,
        quality = quality,
        slot = slot,
    })
end)

RegisterNetEvent('node7-wagon-carcasses:server:confirmLoaded', function(recordId)
    local source = source
    local loader = citizenId(source)
    recordId = tonumber(recordId)
    if not loader or not recordId then return end

    local changed = MySQL.update.await([[
        UPDATE `node7_wagon_carcasses`
        SET `live_net_id` = 0, `status` = 'loaded'
        WHERE `id` = ? AND `loaded_by` = ? AND `status` = 'pending_load'
    ]], { recordId, loader })

    if changed and changed > 0 then
        notify(source, 'Carcass stored in the wagon.', 'success')
    end
end)

RegisterNetEvent('node7-wagon-carcasses:server:loadFailed', function(recordId, reason)
    local source = source
    local loader = citizenId(source)
    recordId = tonumber(recordId)
    if not loader or not recordId then return end

    MySQL.query.await([[
        DELETE FROM `node7_wagon_carcasses`
        WHERE `id` = ? AND `loaded_by` = ? AND `status` = 'pending_load'
    ]], { recordId, loader })

    debugPrint(('load failed id=%s src=%s reason=%s'):format(recordId, source, tostring(reason)))
    notify(source, 'The carcass was not loaded.', 'error')
end)

RegisterNetEvent('node7-wagon-carcasses:server:list', function(wagonid, wagonNetId)
    local source = source
    wagonid = tostring(wagonid or '')
    wagonNetId = tonumber(wagonNetId) or 0

    local wagon, _, reason = validateWagonAccess(source, wagonid, wagonNetId)
    if not wagon then
        notify(source, reason == 'wagon_locked' and 'This wagon is locked.' or 'You cannot access this wagon.', 'error')
        return
    end

    local records = MySQL.query.await([[
        SELECT `id`, `wagonid`, `animal_model` AS `model`, `animal_model_name`,
               `label`, `group_name`, `is_skinned`, `meta_outfit_hash`, `meta_tags`,
               `damage_cleanliness`, `quality`, `slot`, `live_net_id`, `created_at`
        FROM `node7_wagon_carcasses`
        WHERE `wagonid` = ? AND `status` = 'loaded'
        ORDER BY `slot` ASC
    ]], { wagonid }) or {}

    TriggerClientEvent('node7-wagon-carcasses:client:list', source, records, wagonid, wagonNetId)
end)

RegisterNetEvent('node7-wagon-carcasses:server:requestUnload', function(payload)
    local source = source
    payload = type(payload) == 'table' and payload or {}

    local recordId = tonumber(payload.id)
    local wagonid = tostring(payload.wagonid or '')
    local wagonNetId = tonumber(payload.wagonNetId) or 0
    if not recordId or wagonid == '' or wagonNetId == 0 then return end

    local wagon, _, reason = validateWagonAccess(source, wagonid, wagonNetId)
    if not wagon then
        notify(source, reason == 'wagon_locked' and 'This wagon is locked.' or 'You cannot access this wagon.', 'error')
        return
    end

    local changed = MySQL.update.await([[
        UPDATE `node7_wagon_carcasses`
        SET `status` = 'pending_unload'
        WHERE `id` = ? AND `wagonid` = ? AND `status` = 'loaded'
    ]], { recordId, wagonid })

    if not changed or changed < 1 then
        notify(source, 'That carcass is no longer available.', 'error')
        return
    end

    local record = MySQL.single.await([[
        SELECT `id`, `wagonid`, `animal_model` AS `model`, `animal_model_name`,
               `label`, `group_name`, `is_skinned`, `meta_outfit_hash`, `meta_tags`,
               `damage_cleanliness`, `quality`, `slot`, `live_net_id`
        FROM `node7_wagon_carcasses`
        WHERE `id` = ? AND `wagonid` = ? AND `status` = 'pending_unload'
        LIMIT 1
    ]], { recordId, wagonid })

    if not record then return end

    PendingUnloads[recordId] = {
        source = source,
        citizenid = citizenId(source),
        wagonid = wagonid,
        wagonNetId = wagonNetId,
        model = tonumber(record.model) or 0,
        expires = os.time() + math.max(30, math.floor(tonumber(Config.PendingUnloadTimeoutSeconds) or 45)),
    }

    TriggerClientEvent('node7-wagon-carcasses:client:unload', source, record, wagonNetId)
end)

RegisterNetEvent('node7-wagon-carcasses:server:confirmUnloaded', function(recordId, spawnedNetId)
    local source = source
    recordId = tonumber(recordId)
    spawnedNetId = tonumber(spawnedNetId) or 0
    if not recordId or spawnedNetId == 0 then return end

    local pending = PendingUnloads[recordId]
    if not pending
        or tonumber(pending.source) ~= tonumber(source)
        or pending.expires < os.time()
        or tostring(pending.citizenid or '') ~= tostring(citizenId(source) or '') then
        TriggerClientEvent('node7-wagon-carcasses:client:unloadRollback', source, recordId)
        return
    end

    local spawned, wagonEntity, validSpawn
    for _ = 1, 30 do
        spawned = getEntity(spawnedNetId)
        wagonEntity = getEntity(pending.wagonNetId)
        validSpawn = spawned and wagonEntity
            and hashEquals(GetEntityModel(spawned), pending.model)
            and isDeadEntity(spawned)
            and entitiesNear(spawned, wagonEntity, 10.0)

        if validSpawn then
            local stateOk, entityState = pcall(function() return Entity(spawned).state end)
            validSpawn = stateOk and entityState and entityState.node7WagonCarcassProcessed == true
        end
        if validSpawn then break end
        Wait(100)
    end

    if not validSpawn then
        MySQL.update.await([[
            UPDATE `node7_wagon_carcasses`
            SET `status` = 'loaded'
            WHERE `id` = ? AND `wagonid` = ? AND `status` = 'pending_unload'
        ]], { recordId, tostring(pending.wagonid) })
        PendingUnloads[recordId] = nil
        TriggerClientEvent('node7-wagon-carcasses:client:unloadRollback', source, recordId)
        notify(source, 'The processed carcass could not be verified and stayed stored.', 'error')
        return
    end

    local changed = MySQL.update.await(
        'DELETE FROM `node7_wagon_carcasses` WHERE `id` = ? AND `wagonid` = ? AND `status` = ?',
        { recordId, tostring(pending.wagonid), 'pending_unload' }
    )

    PendingUnloads[recordId] = nil
    if changed and changed > 0 then
        TriggerClientEvent('node7-wagon-carcasses:client:unloadCommitted', source, recordId)
        notify(source, 'Skinned carcass placed behind the wagon.', 'success')
    else
        TriggerClientEvent('node7-wagon-carcasses:client:unloadRollback', source, recordId)
    end
end)

RegisterNetEvent('node7-wagon-carcasses:server:unloadFailed', function(recordId, reason)
    local source = source
    recordId = tonumber(recordId)
    if not recordId then return end

    local pending = PendingUnloads[recordId]
    if pending and tonumber(pending.source) ~= tonumber(source) then return end

    MySQL.update.await([[
        UPDATE `node7_wagon_carcasses`
        SET `status` = 'loaded'
        WHERE `id` = ? AND `status` = 'pending_unload'
    ]], { recordId })

    PendingUnloads[recordId] = nil
    debugPrint(('unload failed id=%s src=%s reason=%s'):format(recordId, source, tostring(reason)))
    notify(source, 'The carcass stayed safely stored because unloading failed.', 'error')
end)

RegisterNetEvent('node7-wagon-carcasses:server:requestRestore', function(wagonid, wagonNetId)
    local source = source
    wagonid = tostring(wagonid or '')
    wagonNetId = tonumber(wagonNetId) or 0
    if wagonid == '' or wagonNetId == 0 then return end

    local wagon = validateWagonAccess(source, wagonid, wagonNetId)
    if not wagon then return end

    local now = os.time()
    local lock = RestoreLocks[wagonid]
    if lock and lock.expires > now and lock.source ~= source then return end
    RestoreLocks[wagonid] = { source = source, expires = now + 8 }

    MySQL.update.await(
        'UPDATE `node7_wagon_carcasses` SET `live_net_id` = 0 WHERE `wagonid` = ?',
        { wagonid }
    )

    local records = MySQL.query.await([[
        SELECT `id`, `wagonid`, `animal_model` AS `model`, `animal_model_name`,
               `label`, `group_name`, `is_skinned`, `meta_outfit_hash`, `meta_tags`,
               `damage_cleanliness`, `quality`, `slot`, `live_net_id`
        FROM `node7_wagon_carcasses`
        WHERE `wagonid` = ? AND `status` = 'loaded'
        ORDER BY `slot` ASC
    ]], { wagonid }) or {}

    if #records > 0 then
        TriggerClientEvent('node7-wagon-carcasses:client:restore', source, records, wagonid, wagonNetId)
    end
end)

RegisterNetEvent('node7-wagon-carcasses:server:updateLiveEntity', function(recordId, liveNetId, wagonid, wagonNetId)
    local source = source
    recordId = tonumber(recordId)
    liveNetId = tonumber(liveNetId) or 0
    wagonid = tostring(wagonid or '')
    wagonNetId = tonumber(wagonNetId) or 0
    if not recordId or liveNetId == 0 or wagonid == '' then return end

    local wagon = validateWagonAccess(source, wagonid, wagonNetId)
    if not wagon then return end

    local record = MySQL.single.await([[
        SELECT `animal_model`
        FROM `node7_wagon_carcasses`
        WHERE `id` = ? AND `wagonid` = ? AND `status` = 'loaded'
        LIMIT 1
    ]], { recordId, wagonid })
    if not record then return end

    local carcass = validateCarcassEntity(liveNetId, tonumber(record.animal_model))
    if not carcass then return end

    MySQL.update.await(
        'UPDATE `node7_wagon_carcasses` SET `live_net_id` = ? WHERE `id` = ? AND `wagonid` = ?',
        { liveNetId, recordId, wagonid }
    )
end)

RegisterNetEvent('node7-wagon-carcasses:server:markOffline', function(recordId)
    local source = source
    recordId = tonumber(recordId)
    if not recordId then return end

    local record = MySQL.single.await(
        'SELECT `wagonid` FROM `node7_wagon_carcasses` WHERE `id` = ? LIMIT 1',
        { recordId }
    )
    if not record then return end

    local wagon = getWagon(record.wagonid)
    local id = citizenId(source)
    if not wagon or not id then return end

    if tostring(wagon.citizenid) ~= id and not hasSharedKey(wagon.keys, id) then return end

    MySQL.update.await(
        'UPDATE `node7_wagon_carcasses` SET `live_net_id` = 0 WHERE `id` = ?',
        { recordId }
    )
end)

exports('GetWagonCarcasses', function(wagonid)
    return MySQL.query.await([[
        SELECT `id`, `wagonid`, `animal_model` AS `model`, `animal_model_name`,
               `label`, `group_name`, `slot`, `live_net_id`, `status`, `created_at`
        FROM `node7_wagon_carcasses`
        WHERE `wagonid` = ? AND `status` = 'loaded'
        ORDER BY `slot` ASC
    ]], { tostring(wagonid or '') }) or {}
end)

exports('RemoveWagonCarcass', function(wagonid, recordId)
    local changed = MySQL.update.await(
        'DELETE FROM `node7_wagon_carcasses` WHERE `wagonid` = ? AND `id` = ?',
        { tostring(wagonid or ''), tonumber(recordId) or 0 }
    )
    return tonumber(changed) and tonumber(changed) > 0
end)

AddEventHandler('playerDropped', function()
    local dropped = source
    for recordId, pending in pairs(PendingUnloads) do
        if pending and tonumber(pending.source) == tonumber(dropped) then
            PendingUnloads[recordId] = nil
        end
    end
end)
